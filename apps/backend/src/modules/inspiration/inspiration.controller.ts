import {
  BadRequestException,
  Body,
  Controller,
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
import { Public } from '../../common/decorators/public.decorator';
import {
  InspirationQuotesQueryDto,
  ReportQuoteDto,
  UpdateNotificationPreferencesDto,
  WallpapersQueryDto,
} from './dto/inspiration.dto';
import { InspirationService } from './inspiration.service';
import { NestinLocale } from './inspiration.types';

function parseOptionalLocale(locale?: string): NestinLocale | undefined {
  if (!locale) return undefined;
  if (locale === 'en' || locale === 'id') return locale;
  throw new BadRequestException(`Unsupported locale "${locale}". Expected en or id.`);
}

@ApiTags('inspiration')
@Controller('inspiration')
export class InspirationController {
  constructor(private readonly inspirationService: InspirationService) {}

  @Public()
  @Get('quotes')
  @ApiOperation({
    summary: 'Browse published inspirational quotes with category, author, locale, and keyword filters',
  })
  listQuotes(@Query() query: InspirationQuotesQueryDto) {
    return this.inspirationService.listPublicQuotes(query);
  }

  @Public()
  @Get('featured')
  @ApiOperation({ summary: 'Get the backend-scheduled daily featured quote' })
  getFeaturedQuote(@Query('locale') locale?: string) {
    const safeLocale = parseOptionalLocale(locale) ?? 'en';
    return this.inspirationService.getDailyFeaturedQuote(safeLocale);
  }

  @Public()
  @Get('quotes/:id')
  @ApiOperation({ summary: 'Get a single published quote by ID' })
  getQuoteById(
    @Param('id', new PgUuidPipe()) id: string,
    @Query('locale') locale?: string,
  ) {
    return this.inspirationService.getPublicQuoteById(
      id,
      parseOptionalLocale(locale),
    );
  }

  @Public()
  @Get('categories')
  @ApiOperation({ summary: 'List active Inspiration categories managed via Admin CMS' })
  listCategories(@Query('locale') locale?: string) {
    return this.inspirationService.listPublicCategories(
      parseOptionalLocale(locale),
    );
  }

  @Public()
  @Get('authors')
  @ApiOperation({ summary: 'List active quote authors with optional search' })
  listAuthors(@Query('search') search?: string) {
    return this.inspirationService.listPublicAuthors(search);
  }

  @Public()
  @Get('wallpapers')
  @ApiOperation({ summary: 'List published quote card and wallpaper templates' })
  listWallpapers(@Query() query: WallpapersQueryDto) {
    return this.inspirationService.listPublicWallpapers(query);
  }

  @ApiBearerAuth()
  @Get('me/notification-preferences')
  @ApiOperation({
    summary: 'Get authenticated user daily Inspiration notification preferences (opt-in off by default)',
  })
  getNotificationPreferences(@CurrentUser() user: AuthenticatedUser) {
    return this.inspirationService.getNotificationPreferences(user);
  }

  @ApiBearerAuth()
  @Put('me/notification-preferences')
  @ApiOperation({
    summary: 'Update daily Inspiration notification schedule, timezone, categories, and submission alerts',
  })
  updateNotificationPreferences(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    return this.inspirationService.updateNotificationPreferences(user, dto);
  }

  @ApiBearerAuth()
  @Post('quotes/:id/report')
  @ApiOperation({ summary: 'Report a published quote for moderator review' })
  reportQuote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: ReportQuoteDto,
  ) {
    return this.inspirationService.reportQuote(user, id, dto);
  }
}
