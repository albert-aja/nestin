import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { MediaQueryDto } from './dto/media-query.dto';
import { MediaService } from './media.service';

@ApiTags('media')
@Public()
@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get()
  @ApiOperation({
    summary: 'List published wallpapers, inspiration cards, and downloadable media metadata',
  })
  listAssets(@Query() query: MediaQueryDto) {
    return this.mediaService.listAssets(query);
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Retrieve media metadata by slug' })
  findBySlug(@Param('slug') slug: string) {
    return this.mediaService.findBySlug(slug);
  }
}
