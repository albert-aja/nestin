import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SignJWT } from 'jose';
import request from 'supertest';
import { configureApp } from '../src/app.setup';

describe('Nestin Backend API v1 (e2e)', () => {
  let app: INestApplication;
  const testJwtSecret = 'nestin-test-jwt-secret-minimum-32-bytes';

  async function mintTestJwt(userId = '11111111-1111-4111-8111-111111111111') {
    const secret = new TextEncoder().encode(testJwtSecret);
    return new SignJWT({
      email: 'flock@nestin.local',
      app_metadata: { nestin_role: 'user' },
    })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(secret);
  }

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.SUPABASE_JWT_SECRET = testJwtSecret;
    process.env.SUPABASE_URL = '';
    process.env.SUPABASE_ANON_KEY = '';

    // Import AppModule after env vars are set because ConfigModule.forRoot resolves at evaluation time.
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { AppModule } = require('../src/app.module');

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    configureApp(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/system/health responds publicly with health envelope', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/system/health')
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('ok');
    expect(res.body.data.service).toBe('nestin-backend');
    expect(res.body.data.supabase.jwtVerifierReady).toBe(true);
    expect(res.body.meta.requestId).toBeDefined();
  });

  it('GET /api/v1/auth/policy declares guest-first local-first rules', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/auth/policy')
      .expect(200);

    expect(res.body.data.mode).toBe('guest_first');
    expect(res.body.data.authenticationRequiredForCoreApp).toBe(false);
    expect(res.body.data.automaticCloudUploadOnSignup).toBe(false);
  });

  it('GET /api/v1/quotes supports locale filtering and pagination envelope', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/quotes?locale=id&page=1&limit=10')
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data[0].locale).toBe('id');
    expect(res.body.meta.page).toBe(1);
    expect(res.body.meta.totalPages).toBeGreaterThanOrEqual(1);
  });

  it('GET /api/v1/content and /api/v1/media return published starter catalog and structured 404s', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/content/seren-5h-caffeine-guide-en')
      .expect(200);

    const missing = await request(app.getHttpServer())
      .get('/api/v1/content/non-existent-slug')
      .expect(404);
    expect(missing.body.success).toBe(false);
    expect(missing.body.error.code).toBe('NOT_FOUND');

    const mediaRes = await request(app.getHttpServer())
      .get('/api/v1/media?mascotDomain=seren')
      .expect(200);
    expect(mediaRes.body.data.length).toBeGreaterThanOrEqual(1);
    expect(mediaRes.body.data[0].mascotDomain).toBe('seren');
  });

  it('GET /api/v1/config returns remote config and feature flags', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/config')
      .expect(200);

    expect(res.body.data.minSupportedVersion).toBe('1.0.0');
    expect(res.body.data.featureFlags.cloudSyncEnabled).toBe(false);
  });

  it('Enforces JWT guard on protected auth/users/devices endpoints and validates DTOs', async () => {
    const unauth = await request(app.getHttpServer())
      .get('/api/v1/auth/session')
      .expect(401);
    expect(unauth.body.error.code).toBe('UNAUTHORIZED');

    const token = await mintTestJwt();

    const sessionRes = await request(app.getHttpServer())
      .get('/api/v1/auth/session')
      .set('Authorization', `Bearer ${token}`);
    expect({ status: sessionRes.status, body: sessionRes.body }).toMatchObject({
      status: 200,
    });
    expect(sessionRes.body.data.userId).toBe(
      '11111111-1111-4111-8111-111111111111',
    );
    expect(sessionRes.body.data.email).toBe('flock@nestin.local');

    // Non-UUID guestLocalId rejected cleanly by global ValidationPipe
    const badDto = await request(app.getHttpServer())
      .post('/api/v1/auth/guest-migration/prepare')
      .set('Authorization', `Bearer ${token}`)
      .send({ guestLocalId: 'not-a-uuid' })
      .expect(400);
    expect(badDto.body.error.code).toBe('VALIDATION_ERROR');

    const goodMigration = await request(app.getHttpServer())
      .post('/api/v1/auth/guest-migration/prepare')
      .set('Authorization', `Bearer ${token}`)
      .send({
        guestLocalId: '22222222-2222-4222-8222-222222222222',
        preferredLanguage: 'id',
        localRecordCounts: { alarms: 3, tasks: 8 },
      })
      .expect(201);
    expect(goodMigration.body.data.localDataPreserved).toBe(true);
    expect(goodMigration.body.data.cloudSyncOptIn).toBe(false);

    await request(app.getHttpServer())
      .get('/api/v1/users/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(503);
  });
});
