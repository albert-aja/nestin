import React, { useEffect, useMemo, useState } from 'react';
import {
  ApiClientError,
  InspirationAdminClient,
} from './api/inspirationAdminClient';
import { QuoteCardPreviewModal } from './components/QuoteCardPreview';
import {
  AdminSession,
  hasCmsPermission,
  InspirationAuthor,
  InspirationCategory,
  InspirationFeaturedSchedule,
  InspirationModerationLog,
  InspirationNotificationLog,
  InspirationQuote,
  InspirationSubmission,
  InspirationTranslation,
  InspirationWallpaperTemplate,
  NestinLocale,
  NestinRole,
} from './types/inspiration';

type CmsTab =
  | 'quotes'
  | 'submissions'
  | 'featured'
  | 'categories'
  | 'authors'
  | 'wallpapers'
  | 'translations'
  | 'notifications';

interface Props {
  initialClient?: InspirationAdminClient;
  initialSession?: AdminSession | null;
}

function decodeJwtClaims(token: string): Partial<AdminSession> | null {
  try {
    const parts = token.split('.');
    if (parts.length < 2) return null;
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(atob(base64)) as {
      sub?: string;
      email?: string;
      app_metadata?: { nestin_role?: NestinRole; nestin_permissions?: string[] };
    };
    return {
      userId: json.sub ?? '',
      email: json.email ?? '',
      role: json.app_metadata?.nestin_role ?? 'user',
      permissions: json.app_metadata?.nestin_permissions ?? [],
    };
  } catch {
    return null;
  }
}

export const App: React.FC<Props> = ({ initialClient, initialSession = null }) => {
  const [apiBaseUrl, setApiBaseUrl] = useState(
    import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000',
  );
  const [session, setSession] = useState<AdminSession | null>(initialSession);
  const [tokenInput, setTokenInput] = useState('');
  const [authError, setAuthError] = useState<string | null>(null);

  const [activeTab, setActiveTab] = useState<CmsTab>('quotes');
  const [bannerError, setBannerError] = useState<string | null>(null);
  const [bannerSuccess, setBannerSuccess] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // Domain Data
  const [quotes, setQuotes] = useState<InspirationQuote[]>([]);
  const [categories, setCategories] = useState<InspirationCategory[]>([]);
  const [authors, setAuthors] = useState<InspirationAuthor[]>([]);
  const [submissions, setSubmissions] = useState<InspirationSubmission[]>([]);
  const [featured, setFeatured] = useState<InspirationFeaturedSchedule[]>([]);
  const [wallpapers, setWallpapers] = useState<InspirationWallpaperTemplate[]>([]);
  const [translations, setTranslations] = useState<InspirationTranslation[]>([]);
  const [notifLogs, setNotifLogs] = useState<InspirationNotificationLog[]>([]);

  const [previewQuote, setPreviewQuote] = useState<InspirationQuote | null>(null);
  const [historyModal, setHistoryModal] = useState<{
    submissionId: string;
    logs: InspirationModerationLog[];
  } | null>(null);

  // Forms
  const [newQuoteText, setNewQuoteText] = useState('');
  const [newQuoteAuthor, setNewQuoteAuthor] = useState('');
  const [newQuoteCatId, setNewQuoteCatId] = useState('');
  const [newQuoteLocale, setNewQuoteLocale] = useState<NestinLocale>('en');
  const [newQuoteStatus, setNewQuoteStatus] = useState<'DRAFT' | 'PUBLISHED'>(
    'PUBLISHED',
  );

  const [rejectDrafts, setRejectDrafts] = useState<Record<string, string>>({});
  const [featuredQuoteId, setFeaturedQuoteId] = useState('');
  const [featuredLocale, setFeaturedLocale] = useState<NestinLocale>('en');
  const [featuredDate, setFeaturedDate] = useState('2026-11-15');

  const [newCatSlug, setNewCatSlug] = useState('');
  const [newCatNameEn, setNewCatNameEn] = useState('');
  const [newCatNameId, setNewCatNameId] = useState('');

  const [newAuthorName, setNewAuthorName] = useState('');
  const [newAuthorBio, setNewAuthorBio] = useState('');

  const [newWallName, setNewWallName] = useState('');
  const [newWallSlug, setNewWallSlug] = useState('');
  const [newWallLayout, setNewWallLayout] = useState<
    'quote_card_portrait' | 'quote_card_square' | 'lock_screen' | 'home_screen'
  >('quote_card_portrait');

  const [transQuoteId, setTransQuoteId] = useState('');
  const [transLocale, setTransLocale] = useState<NestinLocale>('id');
  const [transText, setTransText] = useState('');
  const [transAuthor, setTransAuthor] = useState('');

  const client = useMemo(
    () =>
      initialClient ??
      new InspirationAdminClient(apiBaseUrl, () => session?.accessToken ?? ''),
    [initialClient, apiBaseUrl, session],
  );

  const isAuthorizedStaff =
    session !== null &&
    (session.role === 'admin' || session.role === 'moderator');

  async function refreshAll() {
    if (!isAuthorizedStaff) return;
    setLoading(true);
    setBannerError(null);
    try {
      const [q, c, a, s, f, w, t, l] = await Promise.all([
        client.listQuotes(),
        client.listCategories(),
        client.listAuthors(),
        client.listSubmissions(),
        client.listFeaturedSchedules(),
        client.listWallpapers(),
        client.listTranslations(),
        client.listNotificationLogs(),
      ]);
      setQuotes(q);
      setCategories(c);
      setAuthors(a);
      setSubmissions(s);
      setFeatured(f);
      setWallpapers(w);
      setTranslations(t);
      setNotifLogs(l);
      if (!newQuoteCatId && c.length > 0) setNewQuoteCatId(c[0].id);
      if (!featuredQuoteId && q.length > 0) setFeaturedQuoteId(q[0].id);
      if (!transQuoteId && q.length > 0) setTransQuoteId(q[0].id);
    } catch (err) {
      setBannerError(
        err instanceof ApiClientError || err instanceof Error
          ? err.message
          : 'Failed to load CMS data',
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void refreshAll();
  }, [session]);

  function handleTokenSignIn(e: React.FormEvent) {
    e.preventDefault();
    setAuthError(null);
    const trimmed = tokenInput.trim();
    const decoded = decodeJwtClaims(trimmed);
    if (!decoded || !decoded.userId) {
      setAuthError('Invalid JWT token format. Paste an admin or moderator Supabase JWT.');
      return;
    }
    if (decoded.role !== 'admin' && decoded.role !== 'moderator') {
      setAuthError(
        `Access denied for role "${decoded.role ?? 'user'}". Only admin or moderator accounts can open Nestin CMS.`,
      );
      return;
    }
    setSession({
      accessToken: trimmed,
      userId: decoded.userId,
      email: decoded.email ?? 'staff@nestin.app',
      role: decoded.role,
      permissions: decoded.permissions ?? [],
    });
  }

  async function runAction(
    fn: () => Promise<unknown>,
    successMsg: string,
  ): Promise<void> {
    setBannerError(null);
    setBannerSuccess(null);
    try {
      await fn();
      setBannerSuccess(successMsg);
      await refreshAll();
    } catch (err) {
      setBannerError(
        err instanceof Error ? err.message : 'Operation failed',
      );
    }
  }

  if (!isAuthorizedStaff) {
    return (
      <div className="auth-shell">
        <div className="auth-card">
          <div className="brand-badge">nestin cms</div>
          <h1>Inspiration &amp; Daily Quote Admin</h1>
          <p className="muted">
            Role-protected CMS for editorial quotes, featured scheduling,
            localization, and user submission moderation.
          </p>
          <form onSubmit={handleTokenSignIn} className="stack-form">
            <label>
              Backend API Base URL
              <input
                type="url"
                value={apiBaseUrl}
                onChange={(e) => setApiBaseUrl(e.target.value)}
                required
              />
            </label>
            <label>
              Admin / Moderator Access JWT
              <textarea
                rows={4}
                value={tokenInput}
                onChange={(e) => setTokenInput(e.target.value)}
                placeholder="Paste Supabase JWT with app_metadata.nestin_role = admin | moderator"
                required
              />
            </label>
            {authError && <div className="alert-error">{authError}</div>}
            <button type="submit" className="btn-primary">
              Sign In to CMS
            </button>
          </form>
        </div>
      </div>
    );
  }

  const canCreateQuote = hasCmsPermission(session, 'inspiration.quote.create');
  const canPublishQuote = hasCmsPermission(session, 'inspiration.quote.publish');
  const canManageCategories = hasCmsPermission(session, 'inspiration.category.manage');
  const canManageAuthors = hasCmsPermission(session, 'inspiration.author.manage');
  const canManageFeatured = hasCmsPermission(session, 'inspiration.featured.manage');
  const canApprove = hasCmsPermission(session, 'inspiration.submission.approve');
  const canReject = hasCmsPermission(session, 'inspiration.submission.reject');

  return (
    <div className="cms-layout">
      <aside className="cms-sidebar">
        <div className="sidebar-brand">
          <span className="brand-badge">nestin</span>
          <strong>Inspiration CMS</strong>
          <small className="role-pill">{session.role.toUpperCase()}</small>
        </div>
        <nav className="sidebar-nav">
          {(
            [
              ['quotes', 'Quotes Library'],
              ['submissions', `Submissions (${submissions.filter((s) => s.status === 'PENDING').length})`],
              ['featured', 'Featured Schedule'],
              ['categories', 'Categories'],
              ['authors', 'Authors'],
              ['wallpapers', 'Wallpapers'],
              ['translations', 'Translations'],
              ['notifications', 'Notifications Log'],
            ] as [CmsTab, string][]
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              className={activeTab === id ? 'nav-btn active' : 'nav-btn'}
              onClick={() => setActiveTab(id)}
            >
              {label}
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="user-email">{session.email}</div>
          <button
            type="button"
            className="btn-ghost"
            onClick={() => setSession(null)}
          >
            Sign Out
          </button>
        </div>
      </aside>

      <main className="cms-main">
        <header className="cms-header">
          <div>
            <h2>{activeTab.toUpperCase()}</h2>
          </div>
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void refreshAll()}
            disabled={loading}
          >
            {loading ? 'Refreshing...' : 'Refresh'}
          </button>
        </header>

        {bannerError && <div className="alert-error">{bannerError}</div>}
        {bannerSuccess && <div className="alert-success">{bannerSuccess}</div>}

        {activeTab === 'quotes' && (
          <section className="cms-section">
            {canCreateQuote && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.createQuote({
                        quoteText: newQuoteText,
                        author: newQuoteAuthor,
                        categoryId: newQuoteCatId || undefined,
                        locale: newQuoteLocale,
                        publicationStatus: newQuoteStatus,
                      }),
                    'Quote created in library.',
                  ).then(() => {
                    setNewQuoteText('');
                    setNewQuoteAuthor('');
                  });
                }}
              >
                <h3>Create Curated Quote</h3>
                <textarea
                  rows={2}
                  placeholder="Quote text (5-500 chars)..."
                  value={newQuoteText}
                  onChange={(e) => setNewQuoteText(e.target.value)}
                  required
                />
                <div className="row-inputs">
                  <input
                    placeholder="Author display name"
                    value={newQuoteAuthor}
                    onChange={(e) => setNewQuoteAuthor(e.target.value)}
                    required
                  />
                  <select
                    value={newQuoteCatId}
                    onChange={(e) => setNewQuoteCatId(e.target.value)}
                  >
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                  <select
                    value={newQuoteLocale}
                    onChange={(e) => setNewQuoteLocale(e.target.value as NestinLocale)}
                  >
                    <option value="en">EN</option>
                    <option value="id">ID</option>
                  </select>
                  <select
                    value={newQuoteStatus}
                    onChange={(e) =>
                      setNewQuoteStatus(e.target.value as 'DRAFT' | 'PUBLISHED')
                    }
                  >
                    <option value="PUBLISHED">PUBLISHED</option>
                    <option value="DRAFT">DRAFT</option>
                  </select>
                </div>
                <button type="submit" className="btn-primary">
                  Save Quote
                </button>
              </form>
            )}

            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Quote</th>
                    <th>Author</th>
                    <th>Category</th>
                    <th>Locale</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {quotes.map((q) => (
                    <tr key={q.id}>
                      <td>“{q.quoteText}”</td>
                      <td>{q.author}</td>
                      <td>{q.category}</td>
                      <td>{q.locale.toUpperCase()}</td>
                      <td>
                        <span className={`status-pill status-${q.publicationStatus.toLowerCase()}`}>
                          {q.publicationStatus}
                        </span>
                      </td>
                      <td className="action-cell">
                        <button
                          type="button"
                          className="btn-small"
                          onClick={() => setPreviewQuote(q)}
                        >
                          Preview Card
                        </button>
                        {canPublishQuote && q.publicationStatus !== 'PUBLISHED' && (
                          <button
                            type="button"
                            className="btn-small"
                            onClick={() =>
                              void runAction(() => client.publishQuote(q.id), 'Quote published.')
                            }
                          >
                            Publish
                          </button>
                        )}
                        {canPublishQuote && q.publicationStatus === 'PUBLISHED' && (
                          <button
                            type="button"
                            className="btn-small"
                            onClick={() =>
                              void runAction(
                                () => client.unpublishQuote(q.id),
                                'Quote moved to draft.',
                              )
                            }
                          >
                            Unpublish
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}

        {activeTab === 'submissions' && (
          <section className="cms-section">
            {submissions.length === 0 ? (
              <div className="panel-card">No user quote submissions found.</div>
            ) : (
              submissions.map((sub) => {
                const isOwnSubmission = sub.userId === session.userId;
                return (
                  <div key={sub.id} className="panel-card">
                    <div className="sub-header">
                      <span className={`status-pill status-${sub.status.toLowerCase()}`}>
                        {sub.status}
                      </span>
                      <span className="pill">{sub.categorySlug}</span>
                      <span className="pill">{sub.locale.toUpperCase()}</span>
                      {sub.potentialDuplicateIds.length > 0 && (
                        <span className="alert-badge">
                          Possible Duplicate ({sub.potentialDuplicateIds.length})
                        </span>
                      )}
                      {isOwnSubmission && (
                        <span className="alert-badge">Own Submission (Self-review disabled)</span>
                      )}
                    </div>
                    <p className="sub-quote">“{sub.quoteText}”</p>
                    <p className="muted">
                      Attribution: {sub.anonymousPublication ? 'Anonymous' : sub.authorName ?? 'Contributor'}
                    </p>
                    {sub.rejectionReason && (
                      <p className="alert-error">
                        Rejection reason: {sub.rejectionReason}
                      </p>
                    )}
                    <div className="sub-actions">
                      {sub.status === 'PENDING' && canApprove && (
                        <button
                          type="button"
                          className="btn-primary"
                          disabled={isOwnSubmission}
                          onClick={() =>
                            void runAction(
                              () => client.approveSubmission(sub.id, 'Approved via CMS'),
                              'Submission approved and published.',
                            )
                          }
                        >
                          Approve &amp; Publish
                        </button>
                      )}
                      {sub.status === 'PENDING' && canReject && (
                        <div className="reject-box">
                          <input
                            placeholder="Rejection reason (min 5 chars)..."
                            value={rejectDrafts[sub.id] ?? ''}
                            onChange={(e) =>
                              setRejectDrafts((prev) => ({
                                ...prev,
                                [sub.id]: e.target.value,
                              }))
                            }
                          />
                          <button
                            type="button"
                            className="btn-danger"
                            disabled={
                              isOwnSubmission ||
                              (rejectDrafts[sub.id] ?? '').trim().length < 5
                            }
                            onClick={() =>
                              void runAction(
                                () =>
                                  client.rejectSubmission(
                                    sub.id,
                                    rejectDrafts[sub.id].trim(),
                                  ),
                                'Submission rejected with reason.',
                              )
                            }
                          >
                            Reject
                          </button>
                        </div>
                      )}
                      <button
                        type="button"
                        className="btn-secondary"
                        onClick={async () => {
                          const logs = await client.getSubmissionHistory(sub.id);
                          setHistoryModal({ submissionId: sub.id, logs });
                        }}
                      >
                        Audit History
                      </button>
                    </div>
                  </div>
                );
              })
            )}
          </section>
        )}

        {activeTab === 'featured' && (
          <section className="cms-section">
            {canManageFeatured && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.createFeaturedSchedule({
                        quoteId: featuredQuoteId,
                        locale: featuredLocale,
                        publicationDate: featuredDate,
                        startAt: `${featuredDate}T00:00:00.000Z`,
                        endAt: `${featuredDate}T23:59:59.000Z`,
                        priority: 1,
                      }),
                    'Featured quote scheduled.',
                  );
                }}
              >
                <h3>Schedule Daily Featured Quote</h3>
                <div className="row-inputs">
                  <select
                    value={featuredQuoteId}
                    onChange={(e) => setFeaturedQuoteId(e.target.value)}
                  >
                    {quotes
                      .filter((q) => q.publicationStatus === 'PUBLISHED')
                      .map((q) => (
                        <option key={q.id} value={q.id}>
                          {q.quoteText.slice(0, 56)} ({q.locale})
                        </option>
                      ))}
                  </select>
                  <select
                    value={featuredLocale}
                    onChange={(e) => setFeaturedLocale(e.target.value as NestinLocale)}
                  >
                    <option value="en">EN</option>
                    <option value="id">ID</option>
                  </select>
                  <input
                    type="date"
                    value={featuredDate}
                    onChange={(e) => setFeaturedDate(e.target.value)}
                    required
                  />
                </div>
                <button type="submit" className="btn-primary">
                  Save Schedule
                </button>
              </form>
            )}
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Date</th>
                    <th>Locale</th>
                    <th>Quote</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {featured.map((f) => (
                    <tr key={f.id}>
                      <td>{f.publicationDate}</td>
                      <td>{f.locale.toUpperCase()}</td>
                      <td>{f.quote?.quoteText ?? f.quoteId}</td>
                      <td>
                        {canManageFeatured && (
                          <button
                            type="button"
                            className="btn-small"
                            onClick={() =>
                              void runAction(
                                () => client.deleteFeaturedSchedule(f.id),
                                'Schedule removed.',
                              )
                            }
                          >
                            Remove
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}

        {activeTab === 'categories' && (
          <section className="cms-section">
            {canManageCategories && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.createCategory({
                        slug: newCatSlug,
                        name: newCatNameEn,
                        translations: {
                          en: { name: newCatNameEn },
                          id: { name: newCatNameId || newCatNameEn },
                        },
                      }),
                    'Category saved.',
                  ).then(() => {
                    setNewCatSlug('');
                    setNewCatNameEn('');
                    setNewCatNameId('');
                  });
                }}
              >
                <h3>Add Localized Category</h3>
                <div className="row-inputs">
                  <input
                    placeholder="slug (e.g. calm-mornings)"
                    value={newCatSlug}
                    onChange={(e) => setNewCatSlug(e.target.value)}
                    required
                  />
                  <input
                    placeholder="English Label"
                    value={newCatNameEn}
                    onChange={(e) => setNewCatNameEn(e.target.value)}
                    required
                  />
                  <input
                    placeholder="Indonesian Label"
                    value={newCatNameId}
                    onChange={(e) => setNewCatNameId(e.target.value)}
                  />
                </div>
                <button type="submit" className="btn-primary">
                  Create Category
                </button>
              </form>
            )}
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Slug</th>
                    <th>EN</th>
                    <th>ID</th>
                    <th>Active</th>
                    <th>Toggle</th>
                  </tr>
                </thead>
                <tbody>
                  {categories.map((c) => (
                    <tr key={c.id}>
                      <td>{c.slug}</td>
                      <td>{c.translations.en?.name ?? c.name}</td>
                      <td>{c.translations.id?.name ?? c.name}</td>
                      <td>{c.isActive ? 'Yes' : 'Hidden'}</td>
                      <td>
                        {canManageCategories && (
                          <button
                            type="button"
                            className="btn-small"
                            onClick={() =>
                              void runAction(
                                () =>
                                  client.updateCategory(c.id, {
                                    isActive: !c.isActive,
                                  }),
                                'Category visibility updated.',
                              )
                            }
                          >
                            {c.isActive ? 'Deactivate' : 'Activate'}
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}

        {activeTab === 'authors' && (
          <section className="cms-section">
            {canManageAuthors && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.createAuthor({
                        name: newAuthorName,
                        bio: newAuthorBio,
                      }),
                    'Author created.',
                  ).then(() => {
                    setNewAuthorName('');
                    setNewAuthorBio('');
                  });
                }}
              >
                <h3>Add Quote Author</h3>
                <div className="row-inputs">
                  <input
                    placeholder="Author name"
                    value={newAuthorName}
                    onChange={(e) => setNewAuthorName(e.target.value)}
                    required
                  />
                  <input
                    placeholder="Short bio..."
                    value={newAuthorBio}
                    onChange={(e) => setNewAuthorBio(e.target.value)}
                  />
                </div>
                <button type="submit" className="btn-primary">
                  Add Author
                </button>
              </form>
            )}
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Slug</th>
                    <th>Anonymous Pool</th>
                    <th>Bio</th>
                  </tr>
                </thead>
                <tbody>
                  {authors.map((a) => (
                    <tr key={a.id}>
                      <td>{a.name}</td>
                      <td>{a.slug}</td>
                      <td>{a.isAnonymousOrUnknown ? 'Yes' : 'No'}</td>
                      <td>{a.bio}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}

        {activeTab === 'wallpapers' && (
          <section className="cms-section">
            {hasCmsPermission(session, 'inspiration.wallpaper.manage') && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.createWallpaperTemplate({
                        slug: newWallSlug,
                        name: newWallName,
                        layoutType: newWallLayout,
                        aspectRatio:
                          newWallLayout === 'quote_card_square'
                            ? '1:1'
                            : newWallLayout === 'quote_card_portrait'
                              ? '4:5'
                              : '9:16',
                      }),
                    'Wallpaper template created.',
                  ).then(() => {
                    setNewWallName('');
                    setNewWallSlug('');
                  });
                }}
              >
                <h3>Create Card / Wallpaper Template</h3>
                <div className="row-inputs">
                  <input
                    placeholder="Slug"
                    value={newWallSlug}
                    onChange={(e) => setNewWallSlug(e.target.value)}
                    required
                  />
                  <input
                    placeholder="Template Name"
                    value={newWallName}
                    onChange={(e) => setNewWallName(e.target.value)}
                    required
                  />
                  <select
                    value={newWallLayout}
                    onChange={(e) =>
                      setNewWallLayout(
                        e.target.value as
                          | 'quote_card_portrait'
                          | 'quote_card_square'
                          | 'lock_screen'
                          | 'home_screen',
                      )
                    }
                  >
                    <option value="quote_card_portrait">Quote Card 4:5</option>
                    <option value="quote_card_square">Quote Card 1:1</option>
                    <option value="lock_screen">Lock Screen 9:16</option>
                    <option value="home_screen">Home Screen 9:16</option>
                  </select>
                </div>
                <button type="submit" className="btn-primary">
                  Save Template
                </button>
              </form>
            )}
            <div className="cards-grid">
              {wallpapers.map((w) => (
                <div key={w.id} className="panel-card">
                  <div
                    className="swatch-banner"
                    style={{
                      background: `linear-gradient(135deg, ${w.gradientColors.join(', ')})`,
                      color: w.textColor,
                    }}
                  >
                    <strong>{w.name}</strong>
                    <span>{w.layoutType} • {w.aspectRatio}</span>
                  </div>
                </div>
              ))}
            </div>
          </section>
        )}

        {activeTab === 'translations' && (
          <section className="cms-section">
            {hasCmsPermission(session, 'inspiration.translation.manage') && (
              <form
                className="panel-card form-grid"
                onSubmit={(e) => {
                  e.preventDefault();
                  void runAction(
                    () =>
                      client.upsertTranslation({
                        quoteId: transQuoteId,
                        locale: transLocale,
                        quoteText: transText,
                        authorDisplay: transAuthor || 'Nestin',
                        publicationStatus: 'PUBLISHED',
                      }),
                    'Translation saved.',
                  ).then(() => {
                    setTransText('');
                    setTransAuthor('');
                  });
                }}
              >
                <h3>Upsert Quote Translation</h3>
                <div className="row-inputs">
                  <select
                    value={transQuoteId}
                    onChange={(e) => setTransQuoteId(e.target.value)}
                  >
                    {quotes.map((q) => (
                      <option key={q.id} value={q.id}>
                        {q.quoteText.slice(0, 50)} ({q.locale})
                      </option>
                    ))}
                  </select>
                  <select
                    value={transLocale}
                    onChange={(e) => setTransLocale(e.target.value as NestinLocale)}
                  >
                    <option value="id">ID</option>
                    <option value="en">EN</option>
                  </select>
                  <input
                    placeholder="Localized Author Display"
                    value={transAuthor}
                    onChange={(e) => setTransAuthor(e.target.value)}
                    required
                  />
                </div>
                <textarea
                  rows={2}
                  placeholder="Translated quote text..."
                  value={transText}
                  onChange={(e) => setTransText(e.target.value)}
                  required
                />
                <button type="submit" className="btn-primary">
                  Save Translation
                </button>
              </form>
            )}
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Quote ID</th>
                    <th>Locale</th>
                    <th>Translated Text</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {translations.map((t) => (
                    <tr key={t.id}>
                      <td>{t.quoteId.slice(0, 8)}...</td>
                      <td>{t.locale.toUpperCase()}</td>
                      <td>{t.quoteText}</td>
                      <td>{t.publicationStatus}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}

        {activeTab === 'notifications' && (
          <section className="cms-section">
            <div className="panel-card">
              <button
                type="button"
                className="btn-primary"
                onClick={() =>
                  void runAction(
                    () => client.triggerDailyDispatch(),
                    'Evaluated due daily notifications.',
                  )
                }
              >
                Run Due Daily Dispatch Check
              </button>
            </div>
            <div className="table-card">
              <table>
                <thead>
                  <tr>
                    <th>Type</th>
                    <th>User</th>
                    <th>Local Date</th>
                    <th>Status</th>
                    <th>Attempts</th>
                    <th>Note</th>
                  </tr>
                </thead>
                <tbody>
                  {notifLogs.map((l) => (
                    <tr key={l.id}>
                      <td>{l.notificationType}</td>
                      <td>{l.userId.slice(0, 8)}...</td>
                      <td>{l.scheduledDateLocal}</td>
                      <td>{l.status}</td>
                      <td>{l.attemptCount}</td>
                      <td>{l.errorMessage ?? 'OK'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )}
      </main>

      <QuoteCardPreviewModal
        quote={previewQuote}
        onClose={() => setPreviewQuote(null)}
      />

      {historyModal && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <div className="modal-header">
              <h3>Immutable Moderation Audit Log</h3>
              <button
                type="button"
                className="btn-ghost"
                onClick={() => setHistoryModal(null)}
              >
                Close
              </button>
            </div>
            <ul className="audit-list">
              {historyModal.logs.map((entry) => (
                <li key={entry.id}>
                  <strong>{entry.action}</strong> ({entry.previousStatus} -&gt;{' '}
                  {entry.newStatus})
                  <div className="muted">
                    {entry.remarks ?? '—'} • {entry.createdAt}
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}
    </div>
  );
};
