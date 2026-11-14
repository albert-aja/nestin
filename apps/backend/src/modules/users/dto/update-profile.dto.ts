import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateProfileDto {
  @ApiPropertyOptional({ maxLength: 80 })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @ApiPropertyOptional({ enum: ['en', 'id'] })
  @IsOptional()
  @IsIn(['en', 'id'])
  preferredLanguage?: 'en' | 'id';

  @ApiPropertyOptional({ example: 'Asia/Jakarta' })
  @IsOptional()
  @IsString()
  @MaxLength(64)
  timezone?: string;

  @ApiPropertyOptional({
    description: 'Explicit opt-in flag for future optional cloud sync (P1)',
  })
  @IsOptional()
  @IsBoolean()
  cloudSyncOptIn?: boolean;

  @ApiPropertyOptional({
    description: 'Optional user preferences JSON snapshot for multi-device convenience',
  })
  @IsOptional()
  @IsObject()
  preferencesSnapshot?: Record<string, unknown>;
}
