import { SetMetadata } from '@nestjs/common';

export type NestinRole = 'user' | 'moderator' | 'admin';

export const ROLES_KEY = 'nestin:roles';

/**
 * Future administration & content-moderation role extension point.
 */
export const Roles = (...roles: NestinRole[]) => SetMetadata(ROLES_KEY, roles);
