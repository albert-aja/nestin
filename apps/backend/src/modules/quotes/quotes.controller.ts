import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { QuotesQueryDto } from './dto/quotes-query.dto';
import { QuotesService } from './quotes.service';

@ApiTags('quotes')
@Public()
@Controller('quotes')
export class QuotesController {
  constructor(private readonly quotesService: QuotesService) {}

  @Get()
  @ApiOperation({
    summary: 'List published motivation quotes filtered by locale, category, or mascot',
  })
  listQuotes(@Query() query: QuotesQueryDto) {
    return this.quotesService.listQuotes(query);
  }

  @Get('featured')
  @ApiOperation({ summary: 'Retrieve featured quote of the day' })
  @ApiQuery({ name: 'locale', required: false, enum: ['en', 'id'] })
  getFeatured(@Query('locale') locale?: 'en' | 'id') {
    return this.quotesService.getQuoteOfTheDay(locale === 'id' ? 'id' : 'en');
  }
}
