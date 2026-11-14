import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { SupabaseService } from '../../database/supabase.service';
import { AuthenticatedUser } from '../decorators/current-user.decorator';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly supabaseService: SupabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthenticatedUser }>();

    const token = this.extractBearerToken(request);

    if (!token) {
      if (isPublic) {
        return true;
      }
      throw new UnauthorizedException(
        'Authentication token required. Nestin guest mode operates locally without signing in.',
      );
    }

    try {
      const user = await this.supabaseService.verifyAccessToken(token);
      request.user = user;
      return true;
    } catch (error) {
      if (isPublic) {
        // Public routes continue in guest posture even if an expired token is sent
        return true;
      }
      throw new UnauthorizedException(
        error instanceof Error ? error.message : 'Invalid Supabase access token',
      );
    }
  }

  private extractBearerToken(request: Request): string | null {
    const header = request.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return null;
    }
    const token = header.slice('Bearer '.length).trim();
    return token.length > 0 ? token : null;
  }
}
