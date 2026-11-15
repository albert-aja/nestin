import { useMemo, useRef, useState } from 'react';
import {
  InspirationQuote,
  InspirationTranslation,
  NestinLocale,
} from '../types/inspiration';

export interface BilingualParityEntry {
  quote: InspirationQuote;
  activeIdTranslation: InspirationTranslation | null;
  latestIdTranslation: InspirationTranslation | null;
  isMissingActiveId: boolean;
}

export interface BilingualParitySummary {
  entries: BilingualParityEntry[];
  missingEntries: BilingualParityEntry[];
  totalPublishedEn: number;
  translatedCount: number;
  missingCount: number;
  parityPercent: number;
}

/**
 * Evaluates bilingual EN -> ID translation parity across active published EN quotes.
 * Matches backend resolution rules: only PUBLISHED + isActive `id` translations count.
 */
export function computeBilingualParity(
  quotes: InspirationQuote[],
  translations: InspirationTranslation[],
): BilingualParitySummary {
  const publishedEnQuotes = quotes.filter(
    (q) =>
      q.locale === 'en' &&
      q.publicationStatus === 'PUBLISHED' &&
      q.isActive,
  );

  const entries: BilingualParityEntry[] = publishedEnQuotes.map((quote) => {
    const idCandidates = translations.filter(
      (t) => t.quoteId === quote.id && t.locale === 'id',
    );
    const activeIdTranslation =
      idCandidates.find(
        (t) => t.publicationStatus === 'PUBLISHED' && t.isActive,
      ) ?? null;
    const latestIdTranslation = activeIdTranslation ?? idCandidates[0] ?? null;

    return {
      quote,
      activeIdTranslation,
      latestIdTranslation,
      isMissingActiveId: activeIdTranslation === null,
    };
  });

  const missingEntries = entries.filter((e) => e.isMissingActiveId);
  const totalPublishedEn = entries.length;
  const missingCount = missingEntries.length;
  const translatedCount = totalPublishedEn - missingCount;
  const parityPercent =
    totalPublishedEn === 0
      ? 100
      : Math.round((translatedCount / totalPublishedEn) * 100);

  return {
    entries,
    missingEntries,
    totalPublishedEn,
    translatedCount,
    missingCount,
    parityPercent,
  };
}

interface TranslationsPanelProps {
  quotes: InspirationQuote[];
  translations: InspirationTranslation[];
  canManage: boolean;
  onUpsertTranslation: (payload: {
    quoteId: string;
    locale: NestinLocale;
    quoteText: string;
    authorDisplay: string;
    publicationStatus: 'PUBLISHED';
  }) => Promise<void>;
}

export function TranslationsPanel({
  quotes,
  translations,
  canManage,
  onUpsertTranslation,
}: TranslationsPanelProps) {
  const [onlyMissingId, setOnlyMissingId] = useState(false);
  const [transQuoteId, setTransQuoteId] = useState(quotes[0]?.id ?? '');
  const [transLocale, setTransLocale] = useState<NestinLocale>('id');
  const [transText, setTransText] = useState('');
  const [transAuthor, setTransAuthor] = useState('');
  const textAreaRef = useRef<HTMLTextAreaElement | null>(null);

  const parity = useMemo(
    () => computeBilingualParity(quotes, translations),
    [quotes, translations],
  );

  const selectedQuoteId =
    quotes.some((q) => q.id === transQuoteId)
      ? transQuoteId
      : (quotes[0]?.id ?? '');

  const visibleParityEntries = onlyMissingId
    ? parity.missingEntries
    : parity.entries;

  const missingIdsSet = useMemo(
    () => new Set(parity.missingEntries.map((e) => e.quote.id)),
    [parity.missingEntries],
  );

  function handleToggleOnlyMissing(checked: boolean) {
    setOnlyMissingId(checked);
    if (
      checked &&
      parity.missingEntries.length > 0 &&
      !missingIdsSet.has(selectedQuoteId)
    ) {
      const firstMissing = parity.missingEntries[0].quote;
      setTransQuoteId(firstMissing.id);
      setTransLocale('id');
      setTransAuthor(firstMissing.author);
    }
  }

  function handleQuickTranslate(entry: BilingualParityEntry) {
    setTransQuoteId(entry.quote.id);
    setTransLocale('id');
    setTransAuthor(
      entry.latestIdTranslation?.authorDisplay || entry.quote.author,
    );
    setTransText(entry.latestIdTranslation?.quoteText || '');
    textAreaRef.current?.focus();
  }

  const selectableQuotes =
    onlyMissingId && parity.missingEntries.length > 0
      ? parity.missingEntries.map((e) => e.quote)
      : quotes;

  return (
    <section className="cms-section">
      {/* Batch Translation Progress Meter & Bilingual Parity Filter */}
      <div className="panel-card parity-card">
        <div className="parity-header">
          <div>
            <h3>Bilingual Parity Progress (EN → ID)</h3>
            <p className="muted parity-summary">
              {parity.translatedCount} of {parity.totalPublishedEn} published EN
              quotes have an active ID translation
            </p>
          </div>
          <div className="parity-badges">
            <span
              className={`status-pill ${
                parity.missingCount === 0
                  ? 'status-published'
                  : 'status-pending'
              }`}
            >
              {parity.parityPercent}% Complete
            </span>
            <span
              className={`status-pill ${
                parity.missingCount > 0 ? 'status-missing' : 'status-published'
              }`}
            >
              {parity.missingCount === 0
                ? '100% Bilingual Parity'
                : `${parity.missingCount} Missing Active ID`}
            </span>
          </div>
        </div>

        <div
          className="parity-bar-track"
          role="progressbar"
          aria-label="Published EN to ID translation coverage"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={parity.parityPercent}
        >
          <div
            className={`parity-bar-fill ${
              parity.missingCount === 0 ? 'complete' : ''
            }`}
            style={{ width: `${parity.parityPercent}%` }}
          />
        </div>

        <label className="parity-toggle">
          <input
            type="checkbox"
            checked={onlyMissingId}
            onChange={(e) => handleToggleOnlyMissing(e.target.checked)}
          />
          <span>
            Show only published EN quotes missing active ID translation (
            {parity.missingCount})
          </span>
        </label>
      </div>

      {canManage && (
        <form
          className="panel-card form-grid"
          onSubmit={(e) => {
            e.preventDefault();
            if (!selectedQuoteId) return;
            void onUpsertTranslation({
              quoteId: selectedQuoteId,
              locale: transLocale,
              quoteText: transText,
              authorDisplay: transAuthor || 'Nestin',
              publicationStatus: 'PUBLISHED',
            }).then(() => {
              setTransText('');
              setTransAuthor('');
            });
          }}
        >
          <h3>Upsert Quote Translation</h3>
          <div className="row-inputs">
            <select
              value={selectedQuoteId}
              onChange={(e) => setTransQuoteId(e.target.value)}
            >
              {selectableQuotes.map((q) => (
                <option key={q.id} value={q.id}>
                  {missingIdsSet.has(q.id) ? '[MISSING ID] ' : ''}
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
            ref={textAreaRef}
            rows={2}
            placeholder="Translated quote text..."
            value={transText}
            onChange={(e) => setTransText(e.target.value)}
            required
          />
          <button
            type="submit"
            className="btn-primary"
            disabled={!selectedQuoteId}
          >
            Save Translation
          </button>
        </form>
      )}

      {/* Published EN Bilingual Parity Table */}
      <div className="table-card">
        <div className="parity-header">
          <h3>
            {onlyMissingId
              ? 'Published EN Quotes Missing Active ID Translation'
              : 'Published EN Bilingual Parity'}
          </h3>
          <span className="muted">
            Showing {visibleParityEntries.length} of {parity.totalPublishedEn}{' '}
            published EN quotes
          </span>
        </div>
        {visibleParityEntries.length === 0 ? (
          <p className="muted">
            {onlyMissingId
              ? 'All published EN quotes have an active ID translation!'
              : 'No published active EN quotes found.'}
          </p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Published EN Quote</th>
                <th>Author</th>
                <th>ID Parity</th>
                {canManage && <th>Action</th>}
              </tr>
            </thead>
            <tbody>
              {visibleParityEntries.map((entry) => {
                const { quote, activeIdTranslation, latestIdTranslation } = entry;
                const statusLabel = activeIdTranslation
                  ? 'Active ID'
                  : latestIdTranslation
                    ? `Inactive (${latestIdTranslation.publicationStatus})`
                    : 'Missing ID';

                return (
                  <tr
                    key={quote.id}
                    className={
                      entry.isMissingActiveId ? 'row-missing-id' : undefined
                    }
                  >
                    <td>{quote.quoteText}</td>
                    <td>{quote.author}</td>
                    <td>
                      <span
                        className={`status-pill ${
                          entry.isMissingActiveId
                            ? 'status-missing'
                            : 'status-published'
                        }`}
                      >
                        {statusLabel}
                      </span>
                    </td>
                    {canManage && (
                      <td>
                        <button
                          type="button"
                          className="btn-small"
                          onClick={() => handleQuickTranslate(entry)}
                        >
                          {entry.isMissingActiveId
                            ? 'Translate to ID'
                            : 'Edit ID'}
                        </button>
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Full Translation Records (hidden when focused on Missing Active ID queue) */}
      {!onlyMissingId && (
        <div className="table-card">
          <h3>Saved Translation Records ({translations.length})</h3>
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
      )}
    </section>
  );
}
