import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';

export class ContentQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ example: 'wellness' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string;

  @ApiPropertyOptional({ example: 'sleep' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  tag?: string;

  @ApiPropertyOptional({
    enum: ['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'],
  })
  @IsOptional()
  @IsIn(['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'])
  mascotDomain?: string;
}
