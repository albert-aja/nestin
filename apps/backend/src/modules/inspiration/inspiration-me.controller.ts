import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PgUuidPipe } from '../../common/pipes/pg-uuid.pipe';
import {
  AuthenticatedUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import {
  AddFavoriteDto,
  CreateUserQuoteDto,
  SubmitQuoteDto,
  UpdateUserQuoteDto,
} from './dto/inspiration.dto';
import { InspirationService } from './inspiration.service';

@ApiTags('inspiration')
@ApiBearerAuth()
@Controller('inspiration/me')
export class InspirationMeController {
  constructor(private readonly inspirationService: InspirationService) {}

  @Get('quotes')
  @ApiOperation({ summary: 'List authenticated user personal quotes' })
  listPersonalQuotes(@CurrentUser() user: AuthenticatedUser) {
    return this.inspirationService.listUserQuotes(user);
  }

  @Post('quotes')
  @ApiOperation({ summary: 'Create a personal quote owned by the signed-in user' })
  createPersonalQuote(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateUserQuoteDto,
  ) {
    return this.inspirationService.createUserQuote(user, dto);
  }

  @Put('quotes/:id')
  @ApiOperation({
    summary: 'Edit a personal quote (editing a pending submission moves it back to DRAFT for resubmission)',
  })
  updatePersonalQuote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
    @Body() dto: UpdateUserQuoteDto,
  ) {
    return this.inspirationService.updateUserQuote(user, id, dto);
  }

  @Delete('quotes/:id')
  @ApiOperation({
    summary: 'Delete a personal quote and withdraw any unapproved pending submission',
  })
  deletePersonalQuote(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
  ) {
    return this.inspirationService.deleteUserQuote(user, id);
  }

  @Get('submissions')
  @ApiOperation({ summary: 'List global publication submissions for the signed-in user' })
  listMySubmissions(@CurrentUser() user: AuthenticatedUser) {
    return this.inspirationService.listMySubmissions(user);
  }

  @Post('submissions')
  @ApiOperation({ summary: 'Submit a personal quote for global moderator review' })
  submitForModeration(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: SubmitQuoteDto,
  ) {
    return this.inspirationService.submitUserQuoteForModeration(user, dto);
  }

  @Post('submissions/:id/withdraw')
  @ApiOperation({ summary: 'Withdraw a pending quote submission before moderation' })
  withdrawSubmission(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', new PgUuidPipe()) id: string,
  ) {
    return this.inspirationService.withdrawSubmission(user, id);
  }

  @Get('favorites')
  @ApiOperation({ summary: 'List cloud-synced favorite inspirational quotes' })
  listFavorites(@CurrentUser() user: AuthenticatedUser) {
    return this.inspirationService.listFavorites(user);
  }

  @Post('favorites')
  @ApiOperation({ summary: 'Save a published quote to cloud favorites' })
  addFavorite(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: AddFavoriteDto,
  ) {
    return this.inspirationService.addFavorite(user, dto.quoteId);
  }

  @Delete('favorites/:quoteId')
  @ApiOperation({ summary: 'Remove a quote from cloud favorites' })
  removeFavorite(
    @CurrentUser() user: AuthenticatedUser,
    @Param('quoteId', new PgUuidPipe()) quoteId: string,
  ) {
    return this.inspirationService.removeFavorite(user, quoteId);
  }
}
