export type MascotDomain =
  | 'roo'
  | 'echo'
  | 'seren'
  | 'pippin'
  | 'twill'
  | 'scout'
  | 'flock';

export type NestinLocale = 'en' | 'id';
export type QuoteOriginType = 'SYSTEM' | 'USER';
export type PublicationStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type SubmissionStatus =
  | 'DRAFT'
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'WITHDRAWN';
export type NotificationFrequency = 'DAILY' | 'WEEKDAYS' | 'WEEKLY';
export type NotificationType =
  | 'DAILY_INSPIRATION'
  | 'SUBMISSION_APPROVED'
  | 'SUBMISSION_REJECTED';

export interface InspirationAuthorRecord {
  id: string;
  name: string;
  slug: string;
  bio: string;
  isAnonymousOrUnknown: boolean;
  mascotDomain: MascotDomain | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface InspirationCategoryRecord {
  id: string;
  slug: string;
  defaultLocale: NestinLocale;
  name: string;
  description: string;
  translations: Record<string, { name: string; description?: string }>;
  mascotDomain: MascotDomain | null;
  sortOrder: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface InspirationQuoteRecord {
  id: string;
  quoteText: string;
  author: string;
  authorId: string | null;
  category: string;
  categoryId: string | null;
  locale: NestinLocale;
  mascotDomain: MascotDomain | null;
  originType: QuoteOriginType;
  createdByUserId: string | null;
  publicationStatus: PublicationStatus;
  isActive: boolean;
  isFeatured: boolean;
  scheduledFor: string | null;
  sourceReference: string | null;
  backgroundAssetUrl: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface InspirationTranslationRecord {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  quoteText: string;
  authorDisplay: string;
  publicationStatus: PublicationStatus;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationFeaturedScheduleRecord {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  publicationDate: string;
  startAt: string;
  endAt: string;
  priority: number;
  isActive: boolean;
  quote?: InspirationQuoteRecord;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationUserQuoteRecord {
  id: string;
  userId: string;
  quoteText: string;
  authorName: string | null;
  categoryId: string;
  categorySlug: string;
  locale: NestinLocale;
  sourceReference: string | null;
  displayPreference: 'username' | 'anonymous';
  rightsConfirmed: boolean;
  isPersonalOnly: boolean;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface InspirationSubmissionRecord {
  id: string;
  userQuoteId: string;
  userId: string;
  status: SubmissionStatus;
  anonymousPublication: boolean;
  contentFingerprint: string;
  submittedAt: string | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  rejectionReason: string | null;
  publishedQuoteId: string | null;
  quoteText: string;
  authorName: string | null;
  categoryId: string;
  categorySlug: string;
  locale: NestinLocale;
  sourceReference: string | null;
  potentialDuplicateIds: string[];
  createdAt: string;
  updatedAt: string;
}

export interface InspirationModerationLogRecord {
  id: string;
  submissionId: string;
  actorUserId: string;
  previousStatus: SubmissionStatus;
  newStatus: SubmissionStatus;
  action: 'SUBMIT' | 'APPROVE' | 'REJECT' | 'WITHDRAW' | 'RESUBMIT_REQUIRED';
  remarks: string | null;
  createdAt: string;
}

export interface InspirationFavoriteRecord {
  id: string;
  userId: string;
  quoteId: string;
  createdAt: string;
}

export interface InspirationWallpaperTemplateRecord {
  id: string;
  slug: string;
  name: string;
  layoutType:
    | 'quote_card_portrait'
    | 'quote_card_square'
    | 'lock_screen'
    | 'home_screen';
  aspectRatio: string;
  assetId: string | null;
  assetUrl: string | null;
  backgroundType: 'gradient' | 'solid' | 'image';
  gradientColors: string[];
  textColor: string;
  fontFamily: string;
  textAlignment: 'left' | 'center' | 'right';
  showBranding: boolean;
  mascotIllustration: MascotDomain | null;
  locale: NestinLocale | null;
  isPublished: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface InspirationNotificationPreferenceRecord {
  id: string;
  userId: string;
  dailyEnabled: boolean;
  submissionUpdatesEnabled: boolean;
  preferredTime: string;
  timezone: string;
  frequency: NotificationFrequency;
  preferredLocale: NestinLocale;
  preferredCategoryIds: string[];
  lastDispatchedLocalDate: string | null;
  lastSentQuoteId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationNotificationLogRecord {
  id: string;
  userId: string;
  deviceId: string | null;
  notificationType: NotificationType;
  quoteId: string | null;
  submissionId: string | null;
  scheduledDateLocal: string;
  status: 'QUEUED' | 'SENT' | 'FAILED' | 'SKIPPED';
  attemptCount: number;
  dedupeKey: string;
  errorMessage: string | null;
  sentAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationQuoteReportRecord {
  id: string;
  quoteId: string;
  reporterUserId: string;
  reason: string;
  details: string | null;
  status: 'OPEN' | 'REVIEWED';
  createdAt: string;
}
