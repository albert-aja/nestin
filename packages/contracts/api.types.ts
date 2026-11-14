/**
 * Shared Nestin v1 API & Sync Foundation Contracts.
 * Mirrored in Dart inside apps/mobile and in NestJS DTOs inside apps/backend.
 */

export type NestinLocale = 'en' | 'id';
export type MascotDomain =
  | 'roo'
  | 'echo'
  | 'seren'
  | 'pippin'
  | 'twill'
  | 'scout'
  | 'flock';

export type SyncStatus = 'local_only' | 'pending_push' | 'synced' | 'conflict';

export interface SyncableRecordMetadata {
  id: string;
  createdAt: string;
  updatedAt: string;
  deletedAt: string | null;
}

export interface ApiMeta {
  timestamp: string;
  requestId?: string;
  path?: string;
}

export interface PaginationMeta extends ApiMeta {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}

export interface ApiSuccessEnvelope<T> {
  success: true;
  data: T;
  meta: ApiMeta | PaginationMeta;
}

export interface ApiErrorEnvelope {
  success: false;
  error: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta: ApiMeta;
}

export interface UserProfileContract extends SyncableRecordMetadata {
  guestLocalId: string | null;
  displayName: string;
  preferredLanguage: NestinLocale;
  timezone: string;
  role: 'user' | 'moderator' | 'admin';
  cloudSyncOptIn: boolean;
  migratedFromGuestAt: string | null;
}

export interface DeviceRegistrationContract extends SyncableRecordMetadata {
  userId: string;
  deviceIdentifier: string;
  platform: 'android' | 'ios' | 'web' | 'desktop' | 'other';
  deviceName: string | null;
  osVersion: string | null;
  appVersion: string | null;
  pushProvider: 'fcm' | 'apns' | 'none' | null;
  lastSeenAt: string;
  revokedAt: string | null;
}

export interface RemoteConfigContract {
  environment: 'development' | 'staging' | 'production';
  minSupportedVersion: string;
  latestVersion: string;
  maintenanceMode: boolean;
  maintenanceMessageEn: string | null;
  maintenanceMessageId: string | null;
  featureFlags: Record<string, boolean>;
  configVersion: number;
}

// =============================================================================
// Inspiration & Daily Quote Contracts
// =============================================================================

export type InspirationQuoteOrigin = 'SYSTEM' | 'USER';
export type InspirationPublicationStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type InspirationSubmissionStatus =
  | 'DRAFT'
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'WITHDRAWN';
export type InspirationNotificationType =
  | 'DAILY_INSPIRATION'
  | 'SUBMISSION_APPROVED'
  | 'SUBMISSION_REJECTED';
export type InspirationNotificationFrequency = 'DAILY' | 'WEEKDAYS' | 'WEEKLY';

export type InspirationPermission =
  | 'inspiration.quote.view'
  | 'inspiration.quote.create'
  | 'inspiration.quote.update'
  | 'inspiration.quote.publish'
  | 'inspiration.submission.view'
  | 'inspiration.submission.approve'
  | 'inspiration.submission.reject'
  | 'inspiration.category.manage'
  | 'inspiration.author.manage'
  | 'inspiration.featured.manage'
  | 'inspiration.wallpaper.manage'
  | 'inspiration.translation.manage';

export interface InspirationAuthorContract extends SyncableRecordMetadata {
  name: string;
  slug: string;
  bio: string;
  isAnonymousOrUnknown: boolean;
  mascotDomain: MascotDomain | null;
  isActive: boolean;
}

export interface InspirationCategoryContract extends SyncableRecordMetadata {
  slug: string;
  defaultLocale: NestinLocale;
  name: string;
  description: string;
  translations: Record<string, { name: string; description?: string }>;
  mascotDomain: MascotDomain | null;
  sortOrder: number;
  isActive: boolean;
}

export interface InspirationQuoteSourceContract extends SyncableRecordMetadata {
  title: string;
  sourceType: 'book' | 'speech' | 'essay' | 'community' | 'original' | 'other';
  url: string | null;
  notes: string | null;
}

export interface InspirationQuoteTranslationContract {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  quoteText: string;
  authorDisplay: string;
  publicationStatus: InspirationPublicationStatus;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationQuoteContract extends SyncableRecordMetadata {
  quoteText: string;
  author: string;
  authorId: string | null;
  category: string;
  categoryId: string | null;
  locale: NestinLocale;
  mascotDomain: MascotDomain | null;
  originType: InspirationQuoteOrigin;
  createdByUserId: string | null;
  publicationStatus: InspirationPublicationStatus;
  isActive: boolean;
  isFeatured: boolean;
  scheduledFor: string | null;
  sourceReference: string | null;
  backgroundAssetUrl: string | null;
}

export interface InspirationFeaturedScheduleContract {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  publicationDate: string;
  startAt: string;
  endAt: string;
  priority: number;
  isActive: boolean;
  quote?: InspirationQuoteContract;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationUserQuoteContract extends SyncableRecordMetadata {
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
}

export interface InspirationSubmissionContract {
  id: string;
  userQuoteId: string;
  userId: string;
  status: InspirationSubmissionStatus;
  anonymousPublication: boolean;
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
  potentialDuplicateIds?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface InspirationModerationLogContract {
  id: string;
  submissionId: string;
  actorUserId: string;
  previousStatus: InspirationSubmissionStatus;
  newStatus: InspirationSubmissionStatus;
  action: 'SUBMIT' | 'APPROVE' | 'REJECT' | 'WITHDRAW' | 'RESUBMIT_REQUIRED';
  remarks: string | null;
  createdAt: string;
}

export interface InspirationWallpaperTemplateContract
  extends SyncableRecordMetadata {
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
}

export interface InspirationNotificationPreferenceContract {
  id: string;
  userId: string;
  dailyEnabled: boolean;
  submissionUpdatesEnabled: boolean;
  preferredTime: string;
  timezone: string;
  frequency: InspirationNotificationFrequency;
  preferredLocale: NestinLocale;
  preferredCategoryIds: string[];
  lastDispatchedLocalDate: string | null;
  lastSentQuoteId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationNotificationLogContract {
  id: string;
  userId: string;
  deviceId: string | null;
  notificationType: InspirationNotificationType;
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
