import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../../database/supabase.service';

@Injectable()
export class SystemService {
  private readonly startedAt = new Date();

  constructor(
    private readonly configService: ConfigService,
    private readonly supabaseService: SupabaseService,
  ) {}

  getHealth() {
    return {
      status: 'ok',
      service: 'nestin-backend',
      version: this.configService.get<string>('APP_VERSION') ?? '1.0.0',
      uptimeSeconds: Math.floor((Date.now() - this.startedAt.getTime()) / 1000),
      supabase: {
        configured: this.supabaseService.isConfigured,
        jwtVerifierReady: this.supabaseService.hasJwtVerifier,
      },
    };
  }

  async getStatus() {
    const base = this.getHealth();
    let databaseStatus: 'connected' | 'unconfigured' | 'unreachable' =
      'unconfigured';

    const client = this.supabaseService.getPublicClient();
    if (client) {
      try {
        const { error } = await client
          .from('remote_configs')
          .select('id')
          .limit(1);
        databaseStatus = error ? 'unreachable' : 'connected';
      } catch {
        databaseStatus = 'unreachable';
      }
    }

    return {
      ...base,
      environment: this.configService.get<string>('NODE_ENV') ?? 'development',
      databaseStatus,
      localFirstMode: true,
    };
  }
}
