import { ForbiddenException, Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import {
  AdminCreateAuthorDto,
  AdminCreateCategoryDto,
  AdminCreateFeaturedScheduleDto,
  AdminCreateQuoteDto,
  AdminCreateWallpaperTemplateDto,
  AdminSubmissionsQueryDto,
  AdminUpdateAuthorDto,
  AdminUpdateCategoryDto,
  AdminUpdateQuoteDto,
  AdminUpsertTranslationDto,
  ApproveSubmissionDto,
  CreateUserQuoteDto,
  InspirationQuotesQueryDto,
  RejectSubmissionDto,
  ReportQuoteDto,
  SubmitQuoteDto,
  UpdateNotificationPreferencesDto,
  UpdateUserQuoteDto,
  WallpapersQueryDto,
} from './dto/inspiration.dto';
import { InspirationNotificationService } from './inspiration-notification.service';
import { InspirationStore } from './inspiration.store';
import { NestinLocale } from './inspiration.types';

@Injectable()
export class InspirationService {
  constructor(
    private readonly store: InspirationStore,
    private readonly notificationService: InspirationNotificationService,
  ) {}

  private ensureNonGuestAccount(user: AuthenticatedUser): void {
    if (user.isAnonymous) {
      throw new ForbiddenException(
        'Please sign in with a registered Nestin account to manage cloud quotes, submissions, favorites, or notification preferences.',
      );
    }
  }

  // ===========================================================================
  // Public Endpoints
  // ===========================================================================

  listPublicQuotes(query: InspirationQuotesQueryDto) {
    return this.store.listPublicQuotes(query);
  }

  getPublicQuoteById(id: string, locale?: NestinLocale) {
    return this.store.getPublicQuoteById(id, locale);
  }

  getDailyFeaturedQuote(locale: NestinLocale = 'en') {
    return this.store.getDailyFeaturedQuote(locale);
  }

  listPublicCategories(locale?: NestinLocale) {
    return this.store.listPublicCategories(locale);
  }

  listPublicAuthors(search?: string) {
    return this.store.listPublicAuthors(search);
  }

  listPublicWallpapers(query: WallpapersQueryDto) {
    return this.store.listPublicWallpapers(query);
  }

  // ===========================================================================
  // Authenticated User Operations
  // ===========================================================================

  listUserQuotes(user: AuthenticatedUser) {
    this.ensureNonGuestAccount(user);
    return this.store.listUserQuotes(user);
  }

  createUserQuote(user: AuthenticatedUser, dto: CreateUserQuoteDto) {
    this.ensureNonGuestAccount(user);
    return this.store.createUserQuote(user, dto);
  }

  updateUserQuote(
    user: AuthenticatedUser,
    quoteId: string,
    dto: UpdateUserQuoteDto,
  ) {
    this.ensureNonGuestAccount(user);
    return this.store.updateUserQuote(user, quoteId, dto);
  }

  deleteUserQuote(user: AuthenticatedUser, quoteId: string) {
    this.ensureNonGuestAccount(user);
    return this.store.deleteUserQuote(user, quoteId);
  }

  listMySubmissions(user: AuthenticatedUser) {
    this.ensureNonGuestAccount(user);
    return this.store.listMySubmissions(user);
  }

  submitUserQuoteForModeration(user: AuthenticatedUser, dto: SubmitQuoteDto) {
    this.ensureNonGuestAccount(user);
    return this.store.submitUserQuoteForModeration(user, dto);
  }

  withdrawSubmission(user: AuthenticatedUser, submissionId: string) {
    this.ensureNonGuestAccount(user);
    return this.store.withdrawSubmission(user, submissionId);
  }

  listFavorites(user: AuthenticatedUser) {
    this.ensureNonGuestAccount(user);
    return this.store.listFavorites(user);
  }

  addFavorite(user: AuthenticatedUser, quoteId: string) {
    this.ensureNonGuestAccount(user);
    return this.store.addFavorite(user, quoteId);
  }

  removeFavorite(user: AuthenticatedUser, quoteId: string) {
    this.ensureNonGuestAccount(user);
    return this.store.removeFavorite(user, quoteId);
  }

  getNotificationPreferences(user: AuthenticatedUser) {
    this.ensureNonGuestAccount(user);
    return this.store.getNotificationPreferences(user);
  }

  updateNotificationPreferences(
    user: AuthenticatedUser,
    dto: UpdateNotificationPreferencesDto,
  ) {
    this.ensureNonGuestAccount(user);
    return this.store.updateNotificationPreferences(user, dto);
  }

  reportQuote(user: AuthenticatedUser, quoteId: string, dto: ReportQuoteDto) {
    this.ensureNonGuestAccount(user);
    return this.store.reportQuote(user, quoteId, dto);
  }

  // ===========================================================================
  // Admin & Moderator CMS Operations
  // ===========================================================================

  adminListQuotes(query: InspirationQuotesQueryDto) {
    return this.store.adminListQuotes(query);
  }

  adminCreateQuote(dto: AdminCreateQuoteDto, admin: AuthenticatedUser) {
    return this.store.adminCreateQuote(dto, admin);
  }

  adminUpdateQuote(id: string, dto: AdminUpdateQuoteDto) {
    return this.store.adminUpdateQuote(id, dto);
  }

  adminSetQuotePublicationStatus(
    id: string,
    status: 'PUBLISHED' | 'DRAFT' | 'ARCHIVED',
  ) {
    return this.store.adminSetQuotePublicationStatus(id, status);
  }

  adminDeleteQuote(id: string) {
    return this.store.adminDeleteQuote(id);
  }

  adminListAuthors() {
    return this.store.adminListAuthors();
  }

  adminCreateAuthor(dto: AdminCreateAuthorDto) {
    return this.store.adminCreateAuthor(dto);
  }

  adminUpdateAuthor(id: string, dto: AdminUpdateAuthorDto) {
    return this.store.adminUpdateAuthor(id, dto);
  }

  adminListCategories() {
    return this.store.adminListCategories();
  }

  adminCreateCategory(dto: AdminCreateCategoryDto) {
    return this.store.adminCreateCategory(dto);
  }

  adminUpdateCategory(id: string, dto: AdminUpdateCategoryDto) {
    return this.store.adminUpdateCategory(id, dto);
  }

  adminListSubmissions(query: AdminSubmissionsQueryDto) {
    return this.store.adminListSubmissions(query);
  }

  adminApproveSubmission(
    admin: AuthenticatedUser,
    submissionId: string,
    dto: ApproveSubmissionDto,
  ) {
    return this.store.adminApproveSubmission(admin, submissionId, dto);
  }

  adminRejectSubmission(
    admin: AuthenticatedUser,
    submissionId: string,
    dto: RejectSubmissionDto,
  ) {
    return this.store.adminRejectSubmission(admin, submissionId, dto);
  }

  adminGetSubmissionHistory(submissionId: string) {
    return this.store.adminGetSubmissionHistory(submissionId);
  }

  adminListFeaturedSchedules() {
    return this.store.adminListFeaturedSchedules();
  }

  adminCreateFeaturedSchedule(dto: AdminCreateFeaturedScheduleDto) {
    return this.store.adminCreateFeaturedSchedule(dto);
  }

  adminDeleteFeaturedSchedule(id: string) {
    return this.store.adminDeleteFeaturedSchedule(id);
  }

  adminListWallpapers() {
    return this.store.adminListWallpapers();
  }

  adminCreateWallpaperTemplate(dto: AdminCreateWallpaperTemplateDto) {
    return this.store.adminCreateWallpaperTemplate(dto);
  }

  adminListTranslations() {
    return this.store.adminListTranslations();
  }

  adminUpsertTranslation(dto: AdminUpsertTranslationDto) {
    return this.store.adminUpsertTranslation(dto);
  }

  listNotificationLogs(userId?: string) {
    return this.notificationService.listLogsForUser(userId);
  }

  triggerDueDailyDispatch(referenceNowUtc?: Date) {
    return this.notificationService.dispatchDueDailyNotifications({
      preferences: this.store.getAllNotificationPreferences(),
      publishedQuotes: this.store.getAllPublishedQuotes(),
      referenceNowUtc,
    });
  }

  retryFailedNotifications(maxAttempts = 3) {
    const quotesById = new Map(
      this.store.getAllPublishedQuotes().map((q) => [q.id, q]),
    );
    return this.notificationService.retryFailedDailyNotifications({
      quotesById,
      maxAttempts,
    });
  }
}
