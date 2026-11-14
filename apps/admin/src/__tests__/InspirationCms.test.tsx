import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { InspirationAdminClient } from '../api/inspirationAdminClient';
import { App } from '../App';
import { AdminSession } from '../types/inspiration';

function buildJwtWithRole(role: string, sub = 'admin-1'): string {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(
    JSON.stringify({
      sub,
      email: `${role}@nestin.app`,
      app_metadata: { nestin_role: role },
    }),
  );
  return `${header}.${payload}.sig`;
}

function createFakeClient(): InspirationAdminClient {
  return {
    listQuotes: vi.fn().mockResolvedValue([
      {
        id: '10000000-0000-0000-0000-000000000001',
        quoteText: 'Small progress is still progress.',
        author: 'Roo',
        authorId: null,
        category: 'motivation',
        categoryId: '51000000-0000-0000-0000-000000000001',
        locale: 'en',
        mascotDomain: 'roo',
        originType: 'SYSTEM',
        publicationStatus: 'PUBLISHED',
        isActive: true,
        isFeatured: true,
        scheduledFor: '2026-11-14',
        sourceReference: null,
        createdAt: '2026-11-14T00:00:00.000Z',
        updatedAt: '2026-11-14T00:00:00.000Z',
      },
    ]),
    listCategories: vi.fn().mockResolvedValue([
      {
        id: '51000000-0000-0000-0000-000000000001',
        slug: 'motivation',
        name: 'Motivation',
        description: '',
        translations: { en: { name: 'Motivation' }, id: { name: 'Motivasi' } },
        mascotDomain: 'roo',
        sortOrder: 1,
        isActive: true,
      },
    ]),
    listAuthors: vi.fn().mockResolvedValue([]),
    listSubmissions: vi.fn().mockResolvedValue([
      {
        id: 'sub-own',
        userQuoteId: 'uq-1',
        userId: 'mod-1',
        status: 'PENDING',
        anonymousPublication: true,
        quoteText: 'Moderator own quote should not be self-approved.',
        authorName: null,
        categoryId: '51000000-0000-0000-0000-000000000001',
        categorySlug: 'motivation',
        locale: 'en',
        sourceReference: null,
        potentialDuplicateIds: [],
        rejectionReason: null,
        publishedQuoteId: null,
        submittedAt: '2026-11-14T00:00:00.000Z',
        reviewedAt: null,
      },
      {
        id: 'sub-user',
        userQuoteId: 'uq-2',
        userId: 'user-99',
        status: 'PENDING',
        anonymousPublication: false,
        quoteText: 'Gentle mornings anchor calm afternoons.',
        authorName: 'Alya',
        categoryId: '51000000-0000-0000-0000-000000000001',
        categorySlug: 'motivation',
        locale: 'en',
        sourceReference: null,
        potentialDuplicateIds: ['10000000-0000-0000-0000-000000000001'],
        rejectionReason: null,
        publishedQuoteId: null,
        submittedAt: '2026-11-14T00:00:00.000Z',
        reviewedAt: null,
      },
    ]),
    listFeaturedSchedules: vi.fn().mockResolvedValue([]),
    listWallpapers: vi.fn().mockResolvedValue([]),
    listTranslations: vi.fn().mockResolvedValue([]),
    listNotificationLogs: vi.fn().mockResolvedValue([]),
    approveSubmission: vi.fn().mockResolvedValue({}),
  } as unknown as InspirationAdminClient;
}

describe('Nestin Inspiration Admin CMS', () => {
  it('blocks non-admin/non-moderator JWTs at login gate', () => {
    render(<App initialClient={createFakeClient()} />);
    const textarea = screen.getByPlaceholderText(/Paste Supabase JWT/i);
    fireEvent.change(textarea, {
      target: { value: buildJwtWithRole('user', 'user-1') },
    });
    fireEvent.click(screen.getByRole('button', { name: /Sign In to CMS/i }));
    expect(screen.getByText(/Access denied for role "user"/i)).toBeInTheDocument();
  });

  it('enforces moderator RBAC (hides quote creation) and disables self-approval on own submission', async () => {
    const modSession: AdminSession = {
      accessToken: 'jwt-mod',
      userId: 'mod-1',
      email: 'moderator@nestin.app',
      role: 'moderator',
      permissions: [],
    };
    const fakeClient = createFakeClient();
    render(<App initialClient={fakeClient} initialSession={modSession} />);

    await waitFor(() => {
      expect(screen.getByText(/Small progress is still progress/i)).toBeInTheDocument();
    });

    // Moderator does NOT have inspiration.quote.create
    expect(screen.queryByText(/Create Curated Quote/i)).not.toBeInTheDocument();

    // Open Submissions queue -> shows own submission disabled + duplicate badge
    fireEvent.click(screen.getByRole('button', { name: /Submissions/i }));
    await waitFor(() => {
      expect(screen.getByText(/Possible Duplicate/i)).toBeInTheDocument();
    });

    const approveButtons = screen.getAllByRole('button', {
      name: /Approve & Publish/i,
    });
    expect(approveButtons[0]).toBeDisabled(); // Own submission
    expect(approveButtons[1]).not.toBeDisabled(); // User submission
  });
});
