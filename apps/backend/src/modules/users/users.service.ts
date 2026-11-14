import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import { SupabaseService } from '../../database/supabase.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

interface ProfileRow {
  id: string;
  guest_local_id: string | null;
  display_name: string;
  preferred_language: 'en' | 'id';
  timezone: string;
  role: 'user' | 'moderator' | 'admin';
  cloud_sync_opt_in: boolean;
  preferences_snapshot: Record<string, unknown>;
  migrated_from_guest_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

@Injectable()
export class UsersService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async getMyProfile(user: AuthenticatedUser) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase profile storage is not configured on this server',
      );
    }

    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const { data, error } = await client
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .is('deleted_at', null)
      .maybeSingle<ProfileRow>();

    if (error) {
      throw new ServiceUnavailableException(error.message);
    }
    if (!data) {
      throw new NotFoundException('User profile not found');
    }

    return this.toContract(data);
  }

  async updateMyProfile(user: AuthenticatedUser, dto: UpdateProfileDto) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase profile storage is not configured on this server',
      );
    }

    const patch: Record<string, unknown> = {};
    if (dto.displayName !== undefined) patch.display_name = dto.displayName;
    if (dto.preferredLanguage !== undefined) {
      patch.preferred_language = dto.preferredLanguage;
    }
    if (dto.timezone !== undefined) patch.timezone = dto.timezone;
    if (dto.cloudSyncOptIn !== undefined) {
      patch.cloud_sync_opt_in = dto.cloudSyncOptIn;
    }
    if (dto.preferencesSnapshot !== undefined) {
      patch.preferences_snapshot = dto.preferencesSnapshot;
    }

    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const { data, error } = await client
      .from('profiles')
      .update(patch)
      .eq('id', user.id)
      .is('deleted_at', null)
      .select('*')
      .maybeSingle<ProfileRow>();

    if (error) {
      throw new ServiceUnavailableException(error.message);
    }
    if (!data) {
      throw new NotFoundException('User profile not found');
    }
    return this.toContract(data);
  }

  async softDeleteMyProfile(user: AuthenticatedUser) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase profile storage is not configured on this server',
      );
    }

    const nowIso = new Date().toISOString();
    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const { error } = await client
      .from('profiles')
      .update({ deleted_at: nowIso, cloud_sync_opt_in: false })
      .eq('id', user.id);

    if (error) {
      throw new ServiceUnavailableException(error.message);
    }

    return {
      userId: user.id,
      status: 'soft_deleted',
      deletedAt: nowIso,
      localDataAffected: false,
    };
  }

  private toContract(row: ProfileRow) {
    return {
      id: row.id,
      guestLocalId: row.guest_local_id,
      displayName: row.display_name,
      preferredLanguage: row.preferred_language,
      timezone: row.timezone,
      role: row.role,
      cloudSyncOptIn: row.cloud_sync_opt_in,
      preferencesSnapshot: row.preferences_snapshot,
      migratedFromGuestAt: row.migrated_from_guest_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      deletedAt: row.deleted_at,
    };
  }
}
