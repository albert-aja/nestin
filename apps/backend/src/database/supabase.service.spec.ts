import { ConfigService } from '@nestjs/config';
import { SignJWT } from 'jose';
import { SupabaseService } from './supabase.service';

describe('SupabaseService', () => {
  it('verifies HS256 Supabase-compatible JWTs and rejects tampered tokens', async () => {
    const secret = 'unit-test-secret-with-at-least-32-chars';
    const configService = {
      get: (key: string) => {
        if (key === 'SUPABASE_JWT_SECRET') return secret;
        return '';
      },
    } as unknown as ConfigService;

    const service = new SupabaseService(configService);
    expect(service.isConfigured).toBe(false);
    expect(service.hasJwtVerifier).toBe(true);

    const token = await new SignJWT({
      email: 'test@nestin.app',
      app_metadata: { nestin_role: 'moderator' },
    })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject('33333333-3333-4333-8333-333333333333')
      .setIssuedAt()
      .setExpirationTime('10m')
      .sign(new TextEncoder().encode(secret));

    const user = await service.verifyAccessToken(token);
    expect(user.id).toBe('33333333-3333-4333-8333-333333333333');
    expect(user.email).toBe('test@nestin.app');
    expect(user.role).toBe('moderator');

    await expect(service.verifyAccessToken(`${token}tamper`)).rejects.toThrow();
  });
});
