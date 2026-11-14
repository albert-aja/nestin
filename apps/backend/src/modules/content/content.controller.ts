import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { ContentService } from './content.service';
import { ContentQueryDto } from './dto/content-query.dto';

@ApiTags('content')
@Public()
@Controller('content')
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @Get()
  @ApiOperation({
    summary: 'List published localized educational articles & public templates',
  })
  listPublished(@Query() query: ContentQueryDto) {
    return this.contentService.listPublished(query);
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Retrieve a published content item by slug' })
  findBySlug(@Param('slug') slug: string) {
    return this.contentService.findBySlug(slug);
  }
}
