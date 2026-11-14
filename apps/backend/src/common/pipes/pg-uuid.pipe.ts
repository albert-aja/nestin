import {
  ArgumentMetadata,
  BadRequestException,
  Injectable,
  PipeTransform,
} from '@nestjs/common';

export const PG_UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Validates standard 8-4-4-4-12 PostgreSQL UUID strings (including seeded
 * deterministic fixture UUIDs as well as RFC 4122 v4/v5 UUIDs).
 */
@Injectable()
export class PgUuidPipe implements PipeTransform<string, string> {
  transform(value: string, metadata: ArgumentMetadata): string {
    if (typeof value !== 'string' || !PG_UUID_REGEX.test(value.trim())) {
      throw new BadRequestException(
        `Validation failed (${metadata.data ?? 'id'} must be a valid UUID)`,
      );
    }
    return value.trim();
  }
}
