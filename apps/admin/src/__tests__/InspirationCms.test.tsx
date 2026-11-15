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
    upsertTranslation: vi.fn().mockResolvedValue({}),
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

  it('displays Batch Translation Progress Meter and filters published EN quotes missing active ID translation', async () => {
    const adminSession: AdminSession = {
      accessToken: 'jwt-admin',
      userId: 'admin-1',
      email: 'admin@nestin.app',
      role: 'admin',
      permissions: [],
    };
    const fakeClient = createFakeClient();
    vi.mocked(fakeClient.listQuotes).mockResolvedValue([
      {
        id: 'en-translated',
        quoteText: 'Already bilingual quote.',
        author: 'Roo',
        authorId: null,
        category: 'motivation',
        categoryId: '51000000-0000-0000-0000-000000000001',
        locale: 'en',
        mascotDomain: 'roo',
        originType: 'SYSTEM',
        publicationStatus: 'PUBLISHED',
        isActive: true,
        isFeatured: false,
        scheduledFor: null,
        sourceReference: null,
        createdAt: '2026-11-14T00:00:00.000Z',
        updatedAt: '2026-11-14T00:00:00.000Z',
      },
      {
        id: 'en-missing',
        quoteText: 'Needs Indonesian translation now.',
        author: 'Pippin',
        authorId: null,
        category: 'motivation',
        categoryId: '51000000-0000-0000-0000-000000000001',
        locale: 'en',
        mascotDomain: 'pippin',
        originType: 'SYSTEM',
        publicationStatus: 'PUBLISHED',
        isActive: true,
        isFeatured: false,
        scheduledFor: null,
        sourceReference: null,
        createdAt: '2026-11-14T00:00:00.000Z',
        updatedAt: '2026-11-14T00:00:00.000Z',
      },
      {
        id: 'en-draft-only-id',
        quoteText: 'Draft translation should still flag missing active ID.',
        author: 'Seren',
        authorId: null,
        category: 'motivation',
        categoryId: '51000000-0000-0000-0000-000000000001',
        locale: 'en',
        mascotDomain: 'seren',
        originType: 'SYSTEM',
        publicationStatus: 'PUBLISHED',
        isActive: true,
        isFeatured: false,
        scheduledFor: null,
        sourceReference: null,
        createdAt: '2026-11-14T00:00:00.000Z',
        updatedAt: '2026-11-14T00:00:00.000Z',
      },
      {
        id: 'en-unpublished',
        quoteText: 'Unpublished draft EN quote excluded from meter.',
        author: 'Echo',
        authorId: null,
        category: 'motivation',
        categoryId: '51000000-0000-0000-0000-000000000001',
        locale: 'en',
        mascotDomain: 'echo',
        originType: 'SYSTEM',
        publicationStatus: 'DRAFT',
        isActive: true,
        isFeatured: false,
        scheduledFor: null,
        sourceReference: null,
        createdAt: '2026-11-14T00:00:00.000Z',
        updatedAt: '2026-11-14T00:00:00.000Z',
      },
    ]);
    vi.mocked(fakeClient.listTranslations).mockResolvedValue([
      {
        id: 'tr-1',
        quoteId: 'en-translated',
        locale: 'id',
        quoteText: 'Kutipan sudah dwibahasa.',
        authorDisplay: 'Roo',
        publicationStatus: 'PUBLISHED',
        isActive: true,
      },
      {
        id: 'tr-2',
        quoteId: 'en-draft-only-id',
        locale: 'id',
        quoteText: 'Masih draf belum aktif.',
        authorDisplay: 'Seren',
        publicationStatus: 'DRAFT',
        isActive: true,
      },
    ]);

    render(<App initialClient={fakeClient} initialSession={adminSession} />);

    await waitFor(() => {
      expect(screen.getByText(/Already bilingual quote\./i)).toBeInTheDocument();
    });

    fireEvent.click(screen.getByRole('button', { name: /Translations/i }));

    await waitFor(() => {
      expect(
        screen.getByText(/Bilingual Parity Progress \(EN → ID\)/i),
      ).toBeInTheDocument();
    });

    // 1 out of 3 published active EN quotes has active PUBLISHED ID translation => 33%
    expect(
      screen.getByText(/1 of 3 published EN quotes have an active ID translation/i),
    ).toBeInTheDocument();
    expect(screen.getByText('33% Complete')).toBeInTheDocument();
    expect(screen.getByText('2 Missing Active ID')).toBeInTheDocument();
    expect(screen.getByRole('progressbar')).toHaveAttribute(
      'aria-valuenow',
      '33',
    );

    // Unpublished EN quote is excluded from parity table
    expect(
      screen.queryByRole('cell', {
        name: /Unpublished draft EN quote excluded from meter\./i,
      }),
    ).not.toBeInTheDocument();

    // Toggle filter: show only published EN quotes missing active ID translation
    const toggle = screen.getByRole('checkbox', {
      name: /Show only published EN quotes missing active ID translation/i,
    });
    fireEvent.click(toggle);

    // Translated quote is hidden from both table & filtered selector; missing/draft quotes remain highlighted
    expect(
      screen.queryByRole('cell', { name: 'Already bilingual quote.' }),
    ).not.toBeInTheDocument();
    const missingRow = screen
      .getByText('Needs Indonesian translation now.')
      .closest('tr');
    expect(missingRow).toHaveClass('row-missing-id');
    expect(screen.getByText('Missing ID')).toBeInTheDocument();
    expect(screen.getByText('Inactive (DRAFT)')).toBeInTheDocument();

    // Quick-fill "Translate to ID" pre-populates quoteId and author and submits cleanly
    const translateButtons = screen.getAllByRole('button', {
      name: /Translate to ID/i,
    });
    fireEvent.click(translateButtons[0]);

    const textarea = screen.getByPlaceholderText(/Translated quote text\.\.\./i);
    fireEvent.change(textarea, {
      target: { value: 'Butuh terjemahan Indonesia sekarang.' },
    });
    fireEvent.click(screen.getByRole('button', { name: /Save Translation/i }));

    await waitFor(() => {
      expect(fakeClient.upsertTranslation).toHaveBeenCalledWith({
        quoteId: 'en-missing',
        locale: 'id',
        quoteText: 'Butuh terjemahan Indonesia sekarang.',
        authorDisplay: 'Pippin',
        publicationStatus: 'PUBLISHED',
      });
    });
  });
});
