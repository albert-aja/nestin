import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { PaginationQueryDto } from '../../../common/dto/pagination-query.dto';

export class QuotesQueryDto extends PaginationQueryDto {
  @ApiPropertyOptional({ example: 'morning' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  category?: string;

  @ApiPropertyOptional({
    enum: ['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'],
  })
  @IsOptional()
  @IsIn(['roo', 'echo', 'seren', 'pippin', 'twill', 'scout', 'flock'])
  mascotDomain?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  @IsBoolean()
  featured?: boolean;
}
