import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';
import { AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { NestinRole } from '../common/decorators/roles.decorator';

@Injectable()
export class SupabaseService {
  private readonly logger = new Logger(SupabaseService.name);
  private readonly supabaseUrl: string;
  private readonly supabaseAnonKey: string;
  private readonly supabaseJwtSecret: string;
  private readonly publicClient: SupabaseClient | null;
  private jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

  constructor(private readonly configService: ConfigService) {
    this.supabaseUrl = this.configService.get<string>('SUPABASE_URL') ?? '';
    this.supabaseAnonKey =
      this.configService.get<string>('SUPABASE_ANON_KEY') ?? '';
    this.supabaseJwtSecret =
      this.configService.get<string>('SUPABASE_JWT_SECRET') ?? '';

    if (this.supabaseUrl && this.supabaseAnonKey) {
      this.publicClient = createClient(this.supabaseUrl, this.supabaseAnonKey, {
        auth: {
          persistSession: false,
          autoRefreshToken: false,
        },
      });
    } else {
      this.publicClient = null;
      this.logger.warn(
        'SUPABASE_URL / SUPABASE_ANON_KEY not configured; public endpoints will serve starter fallback data and authenticated routes will reject logins.',
      );
    }
  }

  get isConfigured(): boolean {
    return this.publicClient !== null;
  }

  get hasJwtVerifier(): boolean {
    return Boolean(this.supabaseJwtSecret || this.publicClient);
  }

  get storagePublicBaseUrl(): string {
    return this.supabaseUrl ? `${this.supabaseUrl}/storage/v1/object/public` : '';
  }

  /**
   * Public read-only Supabase client (anon role under RLS).
   */
  getPublicClient(): SupabaseClient | null {
    return this.publicClient;
  }

  /**
   * User-scoped Supabase client sending the user's Supabase JWT so Row Level Security
   * (RLS) enforces least-privilege directly in PostgreSQL without service-role bypass.
   */
  createUserScopedClient(accessToken: string): SupabaseClient {
    if (!this.supabaseUrl || !this.supabaseAnonKey) {
      throw new ServiceUnavailableException(
        'Supabase infrastructure is not configured on this server',
      );
    }
    return createClient(this.supabaseUrl, this.supabaseAnonKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
      global: {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
    });
  }

  /**
   * Validates a Supabase access JWT and resolves authenticated user identity.
   * Priority:
   * 1. Local HS256 secret verification (SUPABASE_JWT_SECRET)
   * 2. Supabase JWKS asymmetric verification ({SUPABASE_URL}/auth/v1/.well-known/jwks.json)
   * 3. Supabase Auth `getUser(token)` verification
   */
  async verifyAccessToken(token: string): Promise<AuthenticatedUser> {
    if (this.supabaseJwtSecret) {
      const secret = new TextEncoder().encode(this.supabaseJwtSecret);
      const { payload } = await jwtVerify(token, secret, {
        algorithms: ['HS256'],
      });
      return this.mapPayloadToUser(payload, token);
    }

    if (this.supabaseUrl) {
      try {
        if (!this.jwks) {
          this.jwks = createRemoteJWKSet(
            new URL(`${this.supabaseUrl}/auth/v1/.well-known/jwks.json`),
          );
        }
        const { payload } = await jwtVerify(token, this.jwks);
        return this.mapPayloadToUser(payload, token);
      } catch {
        // Fallback to Supabase Auth introspection below if JWKS is unavailable
      }
    }

    if (this.publicClient) {
      const { data, error } = await this.publicClient.auth.getUser(token);
      if (error || !data.user) {
        throw new Error(error?.message ?? 'Supabase session token is invalid');
      }
      const role = this.resolveRole(
        data.user.app_metadata?.nestin_role as string | undefined,
      );
      const permissions = this.resolvePermissions(
        data.user.app_metadata?.nestin_permissions,
      );
      return {
        id: data.user.id,
        email: data.user.email,
        role,
        permissions,
        accessToken: token,
        isAnonymous: Boolean(data.user.is_anonymous),
      };
    }

    throw new Error('Authentication verification is not configured');
  }

  private mapPayloadToUser(
    payload: JWTPayload,
    accessToken: string,
  ): AuthenticatedUser {
    if (!payload.sub) {
      throw new Error('JWT missing subject claim');
    }
    const appMeta = (payload.app_metadata ?? {}) as Record<string, unknown>;
    const role = this.resolveRole(
      typeof appMeta.nestin_role === 'string'
        ? appMeta.nestin_role
        : undefined,
    );
    const permissions = this.resolvePermissions(appMeta.nestin_permissions);
    return {
      id: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : undefined,
      role,
      permissions,
      accessToken,
      isAnonymous: Boolean(payload.is_anonymous),
    };
  }

  private resolvePermissions(rawPermissions: unknown): string[] {
    if (!Array.isArray(rawPermissions)) {
      return [];
    }
    return rawPermissions.filter(
      (item): item is string => typeof item === 'string' && item.length > 0,
    );
  }

  private resolveRole(rawRole?: string): NestinRole {
    if (rawRole === 'admin' || rawRole === 'moderator') {
      return rawRole;
    }
    return 'user';
  }
}
