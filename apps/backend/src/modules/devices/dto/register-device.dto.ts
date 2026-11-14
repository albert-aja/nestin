import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @ApiProperty({ maxLength: 128 })
  @IsString()
  @MaxLength(128)
  deviceIdentifier!: string;

  @ApiProperty({ enum: ['android', 'ios', 'web', 'desktop', 'other'] })
  @IsIn(['android', 'ios', 'web', 'desktop', 'other'])
  platform!: 'android' | 'ios' | 'web' | 'desktop' | 'other';

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  deviceName?: string;

  @ApiPropertyOptional({ maxLength: 40 })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  osVersion?: string;

  @ApiPropertyOptional({ maxLength: 32 })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  appVersion?: string;

  @ApiPropertyOptional({ maxLength: 512 })
  @IsOptional()
  @IsString()
  @MaxLength(512)
  pushToken?: string;

  @ApiPropertyOptional({ enum: ['fcm', 'apns', 'none'] })
  @IsOptional()
  @IsIn(['fcm', 'apns', 'none'])
  pushProvider?: 'fcm' | 'apns' | 'none';
}
