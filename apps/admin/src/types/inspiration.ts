export type NestinRole = 'user' | 'moderator' | 'admin';
export type NestinLocale = 'en' | 'id';
export type PublicationStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
export type SubmissionStatus =
  | 'DRAFT'
  | 'PENDING'
  | 'APPROVED'
  | 'REJECTED'
  | 'WITHDRAWN';

export type NestinPermission =
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

export const ROLE_PERMISSION_MAP: Record<NestinRole, NestinPermission[]> = {
  user: [],
  moderator: [
    'inspiration.quote.view',
    'inspiration.submission.view',
    'inspiration.submission.approve',
    'inspiration.submission.reject',
  ],
  admin: [
    'inspiration.quote.view',
    'inspiration.quote.create',
    'inspiration.quote.update',
    'inspiration.quote.publish',
    'inspiration.submission.view',
    'inspiration.submission.approve',
    'inspiration.submission.reject',
    'inspiration.category.manage',
    'inspiration.author.manage',
    'inspiration.featured.manage',
    'inspiration.wallpaper.manage',
    'inspiration.translation.manage',
  ],
};

export interface AdminSession {
  accessToken: string;
  userId: string;
  email: string;
  role: NestinRole;
  permissions: string[];
}

export function hasCmsPermission(
  session: AdminSession | null,
  permission: NestinPermission,
): boolean {
  if (!session) return false;
  if (session.role !== 'admin' && session.role !== 'moderator') return false;
  const granted = new Set([
    ...(ROLE_PERMISSION_MAP[session.role] ?? []),
    ...session.permissions,
  ]);
  return granted.has(permission);
}

export interface InspirationQuote {
  id: string;
  quoteText: string;
  author: string;
  authorId: string | null;
  category: string;
  categoryId: string | null;
  locale: NestinLocale;
  mascotDomain: string | null;
  originType: 'SYSTEM' | 'USER';
  publicationStatus: PublicationStatus;
  isActive: boolean;
  isFeatured: boolean;
  scheduledFor: string | null;
  sourceReference: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface InspirationAuthor {
  id: string;
  name: string;
  slug: string;
  bio: string;
  isAnonymousOrUnknown: boolean;
  mascotDomain: string | null;
  isActive: boolean;
}

export interface InspirationCategory {
  id: string;
  slug: string;
  name: string;
  description: string;
  translations: Record<string, { name: string; description?: string }>;
  mascotDomain: string | null;
  sortOrder: number;
  isActive: boolean;
}

export interface InspirationSubmission {
  id: string;
  userQuoteId: string;
  userId: string;
  status: SubmissionStatus;
  anonymousPublication: boolean;
  quoteText: string;
  authorName: string | null;
  categoryId: string;
  categorySlug: string;
  locale: NestinLocale;
  sourceReference: string | null;
  potentialDuplicateIds: string[];
  rejectionReason: string | null;
  publishedQuoteId: string | null;
  submittedAt: string | null;
  reviewedAt: string | null;
}

export interface InspirationModerationLog {
  id: string;
  submissionId: string;
  actorUserId: string;
  previousStatus: SubmissionStatus;
  newStatus: SubmissionStatus;
  action: string;
  remarks: string | null;
  createdAt: string;
}

export interface InspirationFeaturedSchedule {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  publicationDate: string;
  startAt: string;
  endAt: string;
  priority: number;
  isActive: boolean;
  quote?: InspirationQuote;
}

export interface InspirationWallpaperTemplate {
  id: string;
  slug: string;
  name: string;
  layoutType: string;
  aspectRatio: string;
  backgroundType: string;
  gradientColors: string[];
  textColor: string;
  fontFamily: string;
  textAlignment: string;
  showBranding: boolean;
  mascotIllustration: string | null;
  isPublished: boolean;
}

export interface InspirationTranslation {
  id: string;
  quoteId: string;
  locale: NestinLocale;
  quoteText: string;
  authorDisplay: string;
  publicationStatus: PublicationStatus;
  isActive: boolean;
}

export interface InspirationNotificationLog {
  id: string;
  userId: string;
  notificationType: string;
  quoteId: string | null;
  scheduledDateLocal: string;
  status: string;
  attemptCount: number;
  errorMessage: string | null;
  createdAt: string;
}
