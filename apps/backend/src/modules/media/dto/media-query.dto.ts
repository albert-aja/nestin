import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';

export class MediaQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({
    enum: [
      'wallpaper',
      'inspiration_card',
      'template_pack',
      'audio_pack',
      'other',
    ],
  })
  @IsOptional()
  @IsIn([
    'wallpaper',
    'inspiration_card',
    'template_pack',
    'audio_pack',
    'other',
  ])
  assetType?: string;

  @ApiPropertyOptional({
    enum: ['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'],
  })
  @IsOptional()
  @IsIn(['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'])
  mascotDomain?: string;
}
