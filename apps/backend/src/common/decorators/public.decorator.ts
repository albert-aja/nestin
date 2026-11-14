import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'nestin:is_public';

/**
 * Marks a route handler or controller as accessible without a Supabase JWT
 * (used for guest-friendly public resources, health checks, and remote config).
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
