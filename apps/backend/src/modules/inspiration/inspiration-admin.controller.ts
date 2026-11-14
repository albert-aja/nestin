import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PgUuidPipe } from '../../common/pipes/pg-uuid.pipe';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
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
  InspirationQuotesQueryDto,
  RejectSubmissionDto,
} from './dto/inspiration.dto';
import { InspirationService } from './inspiration.service';

@ApiTags('inspiration')
@ApiBearerAuth()
@Roles('admin', 'moderator')
@Controller('admin/inspiration')
export class InspirationAdminController {
  constructor(private readonly inspirationService: InspirationService) {}

  // Quotes CMS
  @Get('quotes')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List all Inspiration quotes across publication statuses' })
  listQuotes(@Query() query: InspirationQuotesQueryDto) {
    return this.inspirationService.adminListQuotes(query);
  }

  @Post('quotes')
  @RequirePermissions('inspiration.quote.create')
  @ApiOperation({ summary: 'Create an Inspiration quote in Admin CMS' })
  createQuote(
    @CurrentUser() admin: AuthenticatedUser,
    @Body() dto: AdminCreateQuoteDto,
  ) {
    return this.inspirationService.adminCreateQuote(dto, admin);
  }

  @Put('quotes/:id')
  @RequirePermissions('inspiration.quote.update')
  @ApiOperation({ summary: 'Update quote text, metadata, or status' })
  updateQuote(
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: AdminUpdateQuoteDto,
  ) {
    return this.inspirationService.adminUpdateQuote(id, dto);
  }

  @Post('quotes/:id/publish')
  @RequirePermissions('inspiration.quote.publish')
  @ApiOperation({ summary: 'Publish a quote to the public Inspiration library' })
  publishQuote(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminSetQuotePublicationStatus(
      id,
      'PUBLISHED',
    );
  }

  @Post('quotes/:id/unpublish')
  @RequirePermissions('inspiration.quote.publish')
  @ApiOperation({ summary: 'Move a published quote back to DRAFT status' })
  unpublishQuote(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminSetQuotePublicationStatus(id, 'DRAFT');
  }

  @Post('quotes/:id/archive')
  @RequirePermissions('inspiration.quote.publish')
  @ApiOperation({ summary: 'Archive a quote from public browsing' })
  archiveQuote(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminSetQuotePublicationStatus(
      id,
      'ARCHIVED',
    );
  }

  @Delete('quotes/:id')
  @RequirePermissions('inspiration.quote.update')
  @ApiOperation({ summary: 'Soft-delete a quote in Admin CMS' })
  deleteQuote(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminDeleteQuote(id);
  }

  // Authors CMS
  @Get('authors')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List Inspiration authors' })
  listAuthors() {
    return this.inspirationService.adminListAuthors();
  }

  @Post('authors')
  @RequirePermissions('inspiration.author.manage')
  @ApiOperation({ summary: 'Create an Inspiration author' })
  createAuthor(@Body() dto: AdminCreateAuthorDto) {
    return this.inspirationService.adminCreateAuthor(dto);
  }

  @Put('authors/:id')
  @RequirePermissions('inspiration.author.manage')
  @ApiOperation({ summary: 'Update an Inspiration author' })
  updateAuthor(
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: AdminUpdateAuthorDto,
  ) {
    return this.inspirationService.adminUpdateAuthor(id, dto);
  }

  // Categories CMS
  @Get('categories')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List Inspiration categories' })
  listCategories() {
    return this.inspirationService.adminListCategories();
  }

  @Post('categories')
  @RequirePermissions('inspiration.category.manage')
  @ApiOperation({ summary: 'Create an Inspiration category with localization labels' })
  createCategory(@Body() dto: AdminCreateCategoryDto) {
    return this.inspirationService.adminCreateCategory(dto);
  }

  @Put('categories/:id')
  @RequirePermissions('inspiration.category.manage')
  @ApiOperation({ summary: 'Update category ordering, visibility, or labels' })
  updateCategory(
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: AdminUpdateCategoryDto,
  ) {
    return this.inspirationService.adminUpdateCategory(id, dto);
  }

  // Submission Moderation Queue
  @Get('submissions')
  @RequirePermissions('inspiration.submission.view')
  @ApiOperation({ summary: 'List user quote submissions with duplicate detection metadata' })
  listSubmissions(@Query() query: AdminSubmissionsQueryDto) {
    return this.inspirationService.adminListSubmissions(query);
  }

  @Post('submissions/:id/approve')
  @RequirePermissions('inspiration.submission.approve')
  @ApiOperation({
    summary: 'Approve a PENDING submission (blocks self-approval) and publish globally',
  })
  approveSubmission(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: ApproveSubmissionDto,
  ) {
    return this.inspirationService.adminApproveSubmission(admin, id, dto);
  }

  @Post('submissions/:id/reject')
  @RequirePermissions('inspiration.submission.reject')
  @ApiOperation({ summary: 'Reject a PENDING submission with a mandatory rejection reason' })
  rejectSubmission(
    @CurrentUser() admin: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: RejectSubmissionDto,
  ) {
    return this.inspirationService.adminRejectSubmission(admin, id, dto);
  }

  @Get('submissions/:id/history')
  @RequirePermissions('inspiration.submission.view')
  @ApiOperation({ summary: 'View immutable moderation audit log for a submission' })
  getSubmissionHistory(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminGetSubmissionHistory(id);
  }

  // Featured Schedule CMS
  @Get('featured')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List scheduled daily featured quotes' })
  listFeaturedSchedules() {
    return this.inspirationService.adminListFeaturedSchedules();
  }

  @Post('featured')
  @RequirePermissions('inspiration.featured.manage')
  @ApiOperation({ summary: 'Schedule a daily featured quote (prevents locale window conflicts)' })
  createFeaturedSchedule(@Body() dto: AdminCreateFeaturedScheduleDto) {
    return this.inspirationService.adminCreateFeaturedSchedule(dto);
  }

  @Delete('featured/:id')
  @RequirePermissions('inspiration.featured.manage')
  @ApiOperation({ summary: 'Remove a featured quote schedule' })
  deleteFeaturedSchedule(@Param('id', new PgUuidPipe()) id: string) {
    return this.inspirationService.adminDeleteFeaturedSchedule(id);
  }

  // Wallpapers & Translations CMS
  @Get('wallpapers')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List wallpaper and quote card templates' })
  listWallpapers() {
    return this.inspirationService.adminListWallpapers();
  }

  @Post('wallpapers')
  @RequirePermissions('inspiration.wallpaper.manage')
  @ApiOperation({ summary: 'Create a wallpaper / quote card template' })
  createWallpaper(@Body() dto: AdminCreateWallpaperTemplateDto) {
    return this.inspirationService.adminCreateWallpaperTemplate(dto);
  }

  @Get('translations')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'List localized quote translations' })
  listTranslations() {
    return this.inspirationService.adminListTranslations();
  }

  @Post('translations')
  @RequirePermissions('inspiration.translation.manage')
  @ApiOperation({ summary: 'Create or update a localized quote translation' })
  upsertTranslation(@Body() dto: AdminUpsertTranslationDto) {
    return this.inspirationService.adminUpsertTranslation(dto);
  }

  // Notification Logs & Manual/Cron Dispatch Endpoints
  @Get('notifications/logs')
  @RequirePermissions('inspiration.quote.view')
  @ApiOperation({ summary: 'Inspect notification dispatch audit logs' })
  listNotificationLogs(@Query('userId') userId?: string) {
    return this.inspirationService.listNotificationLogs(userId);
  }

  @Post('notifications/dispatch-due')
  @Roles('admin')
  @RequirePermissions('inspiration.featured.manage')
  @ApiOperation({ summary: 'Trigger due daily Inspiration push dispatches across user timezones' })
  triggerDailyDispatch(@Query('atUtc') atUtc?: string) {
    const parsedDate = atUtc ? new Date(atUtc) : undefined;
    return this.inspirationService.triggerDueDailyDispatch(parsedDate);
  }

  @Post('notifications/retry-failed')
  @Roles('admin')
  @RequirePermissions('inspiration.featured.manage')
  @ApiOperation({ summary: 'Retry previously failed Inspiration push dispatches within retry cap' })
  retryFailedNotifications() {
    return this.inspirationService.retryFailedNotifications();
  }
}
