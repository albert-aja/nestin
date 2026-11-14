import { INestApplication, Type } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SignJWT } from 'jose';
import request from 'supertest';
import { configureApp } from '../src/app.setup';
import { NestinRole } from '../src/common/decorators/roles.decorator';

const TEST_JWT_SECRET =
  'nestin-inspiration-e2e-secret-at-least-32-characters-long';

// Ensure ConfigModule.forRoot() captures test env at module load time
process.env.NODE_ENV = 'test';
process.env.SUPABASE_JWT_SECRET = TEST_JWT_SECRET;
process.env.SUPABASE_URL = '';
process.env.SUPABASE_ANON_KEY = '';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { AppModule } = require('../src/app.module') as {
  AppModule: Type<unknown>;
};

async function signTestJwt(params: {
  userId: string;
  role: NestinRole;
  permissions?: string[];
  isAnonymous?: boolean;
}) {
  return new SignJWT({
    email: `${params.role}@nestin.app`,
    is_anonymous: params.isAnonymous ?? false,
    app_metadata: {
      nestin_role: params.role,
      ...(params.permissions ? { nestin_permissions: params.permissions } : {}),
    },
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(params.userId)
    .setIssuedAt()
    .setExpirationTime('10m')
    .sign(new TextEncoder().encode(TEST_JWT_SECRET));
}

describe('Inspiration & Daily Quote Module (e2e)', () => {
  let app: INestApplication;
  let userToken: string;
  let guestToken: string;
  let moderatorToken: string;
  let adminToken: string;

  const USER_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  const GUEST_ID = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  const MOD_ID = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  const ADMIN_ID = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
  const CATEGORY_ID = '51000000-0000-0000-0000-000000000001';
  const QUOTE_ID_1 = '10000000-0000-0000-0000-000000000001';

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.SUPABASE_JWT_SECRET = TEST_JWT_SECRET;
    process.env.SUPABASE_URL = '';
    process.env.SUPABASE_ANON_KEY = '';

    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    configureApp(app);
    await app.init();

    userToken = await signTestJwt({ userId: USER_ID, role: 'user' });
    guestToken = await signTestJwt({
      userId: GUEST_ID,
      role: 'user',
      isAnonymous: true,
    });
    moderatorToken = await signTestJwt({ userId: MOD_ID, role: 'moderator' });
    adminToken = await signTestJwt({ userId: ADMIN_ID, role: 'admin' });
  });

  afterAll(async () => {
    await app.close();
  });

  it('serves public featured quotes, library filters, categories, authors, and wallpaper templates', async () => {
    const featuredRes = await request(app.getHttpServer())
      .get('/api/v1/inspiration/featured?locale=en')
      .expect(200);
    expect(featuredRes.body.success).toBe(true);
    expect(featuredRes.body.data.quote.quoteText).toBeTruthy();

    const quotesRes = await request(app.getHttpServer())
      .get('/api/v1/inspiration/quotes?category=motivation&locale=en')
      .expect(200);
    expect(quotesRes.body.data.length).toBeGreaterThan(0);

    const catRes = await request(app.getHttpServer())
      .get('/api/v1/inspiration/categories?locale=id')
      .expect(200);
    expect(catRes.body.data.some((c: { name: string }) => c.name === 'Motivasi')).toBe(true);

    const wallRes = await request(app.getHttpServer())
      .get('/api/v1/inspiration/wallpapers?layoutType=lock_screen')
      .expect(200);
    expect(wallRes.body.data.length).toBeGreaterThan(0);
  });

  it('enforces guest restrictions, personal quotes, favorites, and notification opt-out defaults', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/quotes')
      .set('Authorization', `Bearer ${guestToken}`)
      .send({
        quoteText: 'Guest token must not write cloud quotes.',
        categoryId: CATEGORY_ID,
      })
      .expect(403);

    const prefGet = await request(app.getHttpServer())
      .get('/api/v1/inspiration/me/notification-preferences')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
    expect(prefGet.body.data.dailyEnabled).toBe(false);

    const prefPut = await request(app.getHttpServer())
      .put('/api/v1/inspiration/me/notification-preferences')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        dailyEnabled: true,
        preferredTime: '07:30',
        timezone: 'Asia/Jakarta',
        frequency: 'DAILY',
        preferredLocale: 'en',
        preferredCategoryIds: [CATEGORY_ID],
      })
      .expect(200);
    expect(prefPut.body.data.dailyEnabled).toBe(true);
    expect(prefPut.body.data.preferredTime).toBe('07:30');

    await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/favorites')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ quoteId: QUOTE_ID_1 })
      .expect(201);

    const favList = await request(app.getHttpServer())
      .get('/api/v1/inspiration/me/favorites')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
    expect(favList.body.data.some((q: { id: string }) => q.id === QUOTE_ID_1)).toBe(true);
  });

  it('enforces RBAC & moderation workflow: prevents user self-publish, blocks moderator self-approval, and publishes after review', async () => {
    // 1. User creates personal quote and submits for global moderation
    const createRes = await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/quotes')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        quoteText: 'Steady patience builds quiet strength in every season.',
        authorName: 'Nadia',
        categoryId: CATEGORY_ID,
        locale: 'en',
        displayPreference: 'username',
        rightsConfirmed: true,
      })
      .expect(201);
    const personalId = createRes.body.data.id as string;

    const submitRes = await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/submissions')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        userQuoteId: personalId,
        rightsConfirmed: true,
        anonymousPublication: false,
      })
      .expect(201);
    const submissionId = submitRes.body.data.id as string;
    expect(submitRes.body.data.status).toBe('PENDING');

    // 2. Regular user is strictly forbidden from admin/moderation endpoints
    await request(app.getHttpServer())
      .get('/api/v1/admin/inspiration/submissions')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(403);

    await request(app.getHttpServer())
      .post(`/api/v1/admin/inspiration/submissions/${submissionId}/approve`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({})
      .expect(403);

    // 3. Moderator cannot create global admin categories/quotes without admin permission
    await request(app.getHttpServer())
      .post('/api/v1/admin/inspiration/quotes')
      .set('Authorization', `Bearer ${moderatorToken}`)
      .send({
        quoteText: 'Moderator cannot bypass admin quote creation permission.',
        author: 'Mod',
        categoryId: CATEGORY_ID,
      })
      .expect(403);

    // 4. Moderator self-approval is rejected with 403
    const modPersonal = await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/quotes')
      .set('Authorization', `Bearer ${moderatorToken}`)
      .send({
        quoteText: 'Moderator personal reflection pending another reviewer.',
        categoryId: CATEGORY_ID,
        rightsConfirmed: true,
      })
      .expect(201);
    const modSub = await request(app.getHttpServer())
      .post('/api/v1/inspiration/me/submissions')
      .set('Authorization', `Bearer ${moderatorToken}`)
      .send({
        userQuoteId: modPersonal.body.data.id,
        rightsConfirmed: true,
      })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/v1/admin/inspiration/submissions/${modSub.body.data.id}/approve`)
      .set('Authorization', `Bearer ${moderatorToken}`)
      .send({})
      .expect(403);

    // 5. Moderator approves user's submission -> appears in public catalog + audit log
    const approveRes = await request(app.getHttpServer())
      .post(`/api/v1/admin/inspiration/submissions/${submissionId}/approve`)
      .set('Authorization', `Bearer ${moderatorToken}`)
      .send({ remarks: 'Verified original submission.' })
      .expect(201);
    expect(approveRes.body.data.status).toBe('APPROVED');
    const publishedId = approveRes.body.data.publishedQuoteId as string;

    const historyRes = await request(app.getHttpServer())
      .get(`/api/v1/admin/inspiration/submissions/${submissionId}/history`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
    expect(historyRes.body.data.length).toBeGreaterThanOrEqual(2);

    const publicLookup = await request(app.getHttpServer())
      .get(`/api/v1/inspiration/quotes/${publishedId}`)
      .expect(200);
    expect(publicLookup.body.data.quoteText).toContain('Steady patience');

    // 6. Admin unpublishes quote -> no longer returned on public GET by ID
    await request(app.getHttpServer())
      .post(`/api/v1/admin/inspiration/quotes/${publishedId}/unpublish`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);

    await request(app.getHttpServer())
      .get(`/api/v1/inspiration/quotes/${publishedId}`)
      .expect(404);
  });
});
