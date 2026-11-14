import React from 'react';
import { InspirationQuote } from '../types/inspiration';

interface Props {
  quote: InspirationQuote | null;
  onClose: () => void;
}

export const QuoteCardPreviewModal: React.FC<Props> = ({ quote, onClose }) => {
  if (!quote) return null;

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <div className="modal-header">
          <h3>Quote Card Preview</h3>
          <button type="button" className="btn-ghost" onClick={onClose}>
            Close
          </button>
        </div>

        <div className="quote-preview-canvas">
          <div className="preview-badges">
            <span className="pill">{quote.category}</span>
            <span className="pill">{quote.locale.toUpperCase()}</span>
          </div>
          <blockquote className="preview-quote">
            “{quote.quoteText}”
          </blockquote>
          <p className="preview-author">— {quote.author}</p>
          <div className="preview-footer">
            <span className="preview-brand">nestin</span>
            {quote.mascotDomain && (
              <span className="preview-mascot">Bird: {quote.mascotDomain}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
