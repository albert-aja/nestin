import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { PG_UUID_REGEX } from '../../../common/pipes/pg-uuid.pipe';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';
import {
  MascotDomain,
  NestinLocale,
  NotificationFrequency,
  PublicationStatus,
  SubmissionStatus,
} from '../inspiration.types';

const LOCALES: NestinLocale[] = ['en', 'id'];
const MASCOTS: MascotDomain[] = [
  'roo',
  'echo',
  'seren',
  'pippin',
  'twill',
  'scout',
  'flock',
];
const PUB_STATUSES: PublicationStatus[] = ['DRAFT', 'PUBLISHED', 'ARCHIVED'];
const SUB_STATUSES: SubmissionStatus[] = [
  'DRAFT',
  'PENDING',
  'APPROVED',
  'REJECTED',
  'WITHDRAWN',
];
const FREQUENCIES: NotificationFrequency[] = ['DAILY', 'WEEKDAYS', 'WEEKLY'];

export class InspirationQuotesQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  author?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  authorId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) =>
    value === undefined ? undefined : value === true || value === 'true',
  )
  @IsBoolean()
  featured?: boolean;
}

export class WallpapersQueryDto {
  @ApiPropertyOptional({
    enum: [
      'quote_card_portrait',
      'quote_card_square',
      'lock_screen',
      'home_screen',
    ],
  })
  @IsOptional()
  @IsIn([
    'quote_card_portrait',
    'quote_card_square',
    'lock_screen',
    'home_screen',
  ])
  layoutType?:
    | 'quote_card_portrait'
    | 'quote_card_square'
    | 'lock_screen'
    | 'home_screen';

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional({ enum: LOCALES })
  @IsOptional()
  @IsIn(LOCALES)
  locale?: NestinLocale;
}

export class CreateUserQuoteDto {
  @ApiProperty({ minLength: 5, maxLength: 500 })
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  quoteText!: string;

  @ApiPropertyOptional({ maxLength: 120 })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  authorName?: string;

  @ApiProperty()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  categoryId!: string;

  @ApiPropertyOptional({ enum: LOCALES, default: 'en' })
  @IsOptional()
  @IsIn(LOCALES)
  locale?: NestinLocale = 'en';

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  sourceReference?: string;

  @ApiPropertyOptional({ enum: ['username', 'anonymous'], default: 'anonymous' })
  @IsOptional()
  @IsIn(['username', 'anonymous'])
  displayPreference?: 'username' | 'anonymous' = 'anonymous';

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  rightsConfirmed?: boolean = false;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isPersonalOnly?: boolean = true;
}

export class UpdateUserQuoteDto {
  @ApiPropertyOptional({ minLength: 5, maxLength: 500 })
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  quoteText?: string;

  @ApiPropertyOptional({ maxLength: 120 })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  authorName?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  categoryId?: string;

  @ApiPropertyOptional({ enum: LOCALES })
  @IsOptional()
  @IsIn(LOCALES)
  locale?: NestinLocale;

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  sourceReference?: string;

  @ApiPropertyOptional({ enum: ['username', 'anonymous'] })
  @IsOptional()
  @IsIn(['username', 'anonymous'])
  displayPreference?: 'username' | 'anonymous';

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  rightsConfirmed?: boolean;
}

export class SubmitQuoteDto {
  @ApiProperty()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  userQuoteId!: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  anonymousPublication?: boolean = true;

  @ApiProperty()
  @IsBoolean()
  rightsConfirmed!: boolean;
}

export class AddFavoriteDto {
  @ApiProperty()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  quoteId!: string;
}

export class UpdateNotificationPreferencesDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  dailyEnabled?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  submissionUpdatesEnabled?: boolean;

  @ApiPropertyOptional({ example: '08:00' })
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):([0-5]\d)$/)
  preferredTime?: string;

  @ApiPropertyOptional({ example: 'Asia/Jakarta' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;

  @ApiPropertyOptional({ enum: FREQUENCIES })
  @IsOptional()
  @IsIn(FREQUENCIES)
  frequency?: NotificationFrequency;

  @ApiPropertyOptional({ enum: LOCALES })
  @IsOptional()
  @IsIn(LOCALES)
  preferredLocale?: NestinLocale;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(12)
  @Matches(PG_UUID_REGEX, { each: true, message: 'each value must be a valid UUID' })
  preferredCategoryIds?: string[];
}

export class ReportQuoteDto {
  @ApiProperty({ minLength: 3, maxLength: 100 })
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  reason!: string;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  details?: string;
}

// =============================================================================
// Admin CMS DTOs
// =============================================================================

export class AdminCreateQuoteDto {
  @ApiProperty({ minLength: 5, maxLength: 500 })
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  quoteText!: string;

  @ApiProperty({ maxLength: 120 })
  @IsString()
  @MaxLength(120)
  author!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  authorId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ enum: LOCALES, default: 'en' })
  @IsOptional()
  @IsIn(LOCALES)
  locale?: NestinLocale = 'en';

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional({ enum: PUB_STATUSES, default: 'DRAFT' })
  @IsOptional()
  @IsIn(PUB_STATUSES)
  publicationStatus?: PublicationStatus = 'DRAFT';

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean = true;

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  sourceReference?: string;
}

export class AdminUpdateQuoteDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  quoteText?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  author?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  authorId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  categoryId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({ enum: LOCALES })
  @IsOptional()
  @IsIn(LOCALES)
  locale?: NestinLocale;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional({ enum: PUB_STATUSES })
  @IsOptional()
  @IsIn(PUB_STATUSES)
  publicationStatus?: PublicationStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  sourceReference?: string;
}

export class AdminCreateAuthorDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(120)
  slug?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string = '';

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  isAnonymousOrUnknown?: boolean = false;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean = true;
}

export class AdminUpdateAuthorDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isAnonymousOrUnknown?: boolean;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class AdminCreateCategoryDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  slug!: string;

  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string = '';

  @ApiPropertyOptional({ enum: LOCALES, default: 'en' })
  @IsOptional()
  @IsIn(LOCALES)
  defaultLocale?: NestinLocale = 'en';

  @ApiPropertyOptional()
  @IsOptional()
  translations?: Record<string, { name: string; description?: string }>;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number = 10;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean = true;
}

export class AdminUpdateCategoryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  translations?: Record<string, { name: string; description?: string }>;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotDomain?: MascotDomain;

  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

export class AdminSubmissionsQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ enum: SUB_STATUSES })
  @IsOptional()
  @IsIn(SUB_STATUSES)
  status?: SubmissionStatus;
}

export class ApproveSubmissionDto {
  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  remarks?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  overrideCategoryId?: string;
}

export class RejectSubmissionDto {
  @ApiProperty({ minLength: 5, maxLength: 400 })
  @IsString()
  @MinLength(5)
  @MaxLength(400)
  rejectionReason!: string;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  remarks?: string;
}

export class AdminCreateFeaturedScheduleDto {
  @ApiProperty()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  quoteId!: string;

  @ApiProperty({ enum: LOCALES })
  @IsIn(LOCALES)
  locale!: NestinLocale;

  @ApiProperty({ example: '2026-11-15' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  publicationDate!: string;

  @ApiProperty()
  @IsISO8601()
  startAt!: string;

  @ApiProperty()
  @IsISO8601()
  endAt!: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @IsInt()
  @Min(0)
  priority?: number = 1;
}

export class AdminCreateWallpaperTemplateDto {
  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  slug!: string;

  @ApiProperty()
  @IsString()
  @MinLength(2)
  @MaxLength(120)
  name!: string;

  @ApiProperty({
    enum: [
      'quote_card_portrait',
      'quote_card_square',
      'lock_screen',
      'home_screen',
    ],
  })
  @IsIn([
    'quote_card_portrait',
    'quote_card_square',
    'lock_screen',
    'home_screen',
  ])
  layoutType!:
    | 'quote_card_portrait'
    | 'quote_card_square'
    | 'lock_screen'
    | 'home_screen';

  @ApiProperty({ example: '9:16' })
  @IsString()
  aspectRatio!: string;

  @ApiPropertyOptional({ enum: ['gradient', 'solid', 'image'], default: 'gradient' })
  @IsOptional()
  @IsIn(['gradient', 'solid', 'image'])
  backgroundType?: 'gradient' | 'solid' | 'image' = 'gradient';

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  gradientColors?: string[];

  @ApiPropertyOptional({ default: '#FFFFFF' })
  @IsOptional()
  @IsString()
  textColor?: string = '#FFFFFF';

  @ApiPropertyOptional({ default: 'serif' })
  @IsOptional()
  @IsString()
  fontFamily?: string = 'serif';

  @ApiPropertyOptional({ enum: ['left', 'center', 'right'], default: 'center' })
  @IsOptional()
  @IsIn(['left', 'center', 'right'])
  textAlignment?: 'left' | 'center' | 'right' = 'center';

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  showBranding?: boolean = true;

  @ApiPropertyOptional({ enum: MASCOTS })
  @IsOptional()
  @IsIn(MASCOTS)
  mascotIllustration?: MascotDomain;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  assetUrl?: string;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isPublished?: boolean = true;
}

export class AdminUpsertTranslationDto {
  @ApiProperty()
  @Matches(PG_UUID_REGEX, { message: 'must be a valid UUID' })
  quoteId!: string;

  @ApiProperty({ enum: LOCALES })
  @IsIn(LOCALES)
  locale!: NestinLocale;

  @ApiProperty({ minLength: 5, maxLength: 500 })
  @IsString()
  @MinLength(5)
  @MaxLength(500)
  quoteText!: string;

  @ApiProperty({ maxLength: 120 })
  @IsString()
  @MaxLength(120)
  authorDisplay!: string;

  @ApiPropertyOptional({ enum: PUB_STATUSES, default: 'PUBLISHED' })
  @IsOptional()
  @IsIn(PUB_STATUSES)
  publicationStatus?: PublicationStatus = 'PUBLISHED';

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean = true;
}
