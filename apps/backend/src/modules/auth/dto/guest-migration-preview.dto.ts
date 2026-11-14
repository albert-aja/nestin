import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsObject, IsOptional, IsUUID } from 'class-validator';

export class PrepareGuestMigrationDto {
  @ApiProperty({
    format: 'uuid',
    description: 'Local guest profile UUID generated on-device before registration',
  })
  @IsUUID()
  guestLocalId!: string;

  @ApiPropertyOptional({ enum: ['en', 'id'] })
  @IsOptional()
  @IsIn(['en', 'id'])
  preferredLanguage?: 'en' | 'id';

  @ApiPropertyOptional({
    description:
      'Optional record counts kept locally on device (counts only; personal data stays local)',
    example: { alarms: 3, tasks: 12, notes: 5 },
  })
  @IsOptional()
  @IsObject()
  localRecordCounts?: Record<string, number>;
}
