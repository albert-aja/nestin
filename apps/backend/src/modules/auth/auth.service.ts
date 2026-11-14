import { Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import { SupabaseService } from '../../database/supabase.service';
import { PrepareGuestMigrationDto } from './dto/guest-migration-preview.dto';

@Injectable()
export class AuthService {
  constructor(private readonly supabaseService: SupabaseService) {}

  getAuthPolicy() {
    return {
      mode: 'guest_first',
      authenticationRequiredForCoreApp: false,
      automaticCloudUploadOnSignup: false,
      supportedProviders: ['email_password'],
      supabaseConfigured: this.supabaseService.isConfigured,
      notes: [
        'Guest users operate 100% locally on-device with a local UUID.',
        'Signing up links identity without erasing or force-uploading local records.',
        'Cloud backup and multi-device sync remain explicit opt-in capabilities.',
      ],
    };
  }

  getSessionIdentity(user: AuthenticatedUser) {
    return {
      userId: user.id,
      email: user.email ?? null,
      role: user.role,
      isAnonymous: user.isAnonymous,
    };
  }

  async prepareGuestMigration(
    user: AuthenticatedUser,
    dto: PrepareGuestMigrationDto,
  ) {
    const nowIso = new Date().toISOString();

    if (this.supabaseService.isConfigured) {
      const client = this.supabaseService.createUserScopedClient(
        user.accessToken,
      );
      await client
        .from('profiles')
        .update({
          guest_local_id: dto.guestLocalId,
          migrated_from_guest_at: nowIso,
          ...(dto.preferredLanguage
            ? { preferred_language: dto.preferredLanguage }
            : {}),
        })
        .eq('id', user.id);
    }

    return {
      userId: user.id,
      guestLocalId: dto.guestLocalId,
      migratedAt: nowIso,
      localDataPreserved: true,
      cloudSyncOptIn: false,
      acknowledgedLocalCounts: dto.localRecordCounts ?? {},
    };
  }
}
