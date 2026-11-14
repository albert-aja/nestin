import { SetMetadata } from '@nestjs/common';
import { NestinRole } from './roles.decorator';

export type NestinPermission =
  | 'inspiration.quote.view'
  | 'inspiration.quote.create'
  | 'inspiration.quote.update'
  | 'inspiration.quote.publish'
  | 'inspiration.submission.view'
  | 'inspiration.submission.approve'
  | 'inspiration.submission.reject'
  | 'inspiration.category.manage'
  | 'inspiration.author.manage'
  | 'inspiration.featured.manage'
  | 'inspiration.wallpaper.manage'
  | 'inspiration.translation.manage';

export const ALL_INSPIRATION_PERMISSIONS: NestinPermission[] = [
  'inspiration.quote.view',
  'inspiration.quote.create',
  'inspiration.quote.update',
  'inspiration.quote.publish',
  'inspiration.submission.view',
  'inspiration.submission.approve',
  'inspiration.submission.reject',
  'inspiration.category.manage',
  'inspiration.author.manage',
  'inspiration.featured.manage',
  'inspiration.wallpaper.manage',
  'inspiration.translation.manage',
];

export const ROLE_PERMISSION_MAP: Record<NestinRole, NestinPermission[]> = {
  user: [],
  moderator: [
    'inspiration.quote.view',
    'inspiration.submission.view',
    'inspiration.submission.approve',
    'inspiration.submission.reject',
  ],
  admin: ALL_INSPIRATION_PERMISSIONS,
};

export const PERMISSIONS_KEY = 'nestin:permissions';

export const RequirePermissions = (...permissions: NestinPermission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
