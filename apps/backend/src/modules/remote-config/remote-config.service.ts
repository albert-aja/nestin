import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SupabaseService } from '../../database/supabase.service';

export interface RemoteConfigPayload {
  environment: string;
  minSupportedVersion: string;
  latestVersion: string;
  maintenanceMode: boolean;
  maintenanceMessageEn: string | null;
  maintenanceMessageId: string | null;
  featureFlags: Record<string, boolean>;
  configVersion: number;
  source: 'supabase' | 'env_default';
}

@Injectable()
export class RemoteConfigService {
  constructor(
    private readonly configService: ConfigService,
    private readonly supabaseService: SupabaseService,
  ) {}

  async getPublicConfig(): Promise<RemoteConfigPayload> {
    const nodeEnv =
      this.configService.get<string>('NODE_ENV') ?? 'development';
    const targetEnv =
      nodeEnv === 'staging' || nodeEnv === 'production'
        ? nodeEnv
        : 'development';

    const client = this.supabaseService.getPublicClient();
    if (client) {
      const { data } = await client
        .from('remote_configs')
        .select(
          'environment,min_supported_version,latest_version,maintenance_mode,maintenance_message_en,maintenance_message_id,feature_flags,config_version',
        )
        .eq('environment', targetEnv)
        .eq('is_active', true)
        .is('deleted_at', null)
        .maybeSingle();

      if (data) {
        return {
          environment: data.environment as string,
          minSupportedVersion: data.min_supported_version as string,
          latestVersion: data.latest_version as string,
          maintenanceMode: Boolean(data.maintenance_mode),
          maintenanceMessageEn:
            (data.maintenance_message_en as string | null) ?? null,
          maintenanceMessageId:
            (data.maintenance_message_id as string | null) ?? null,
          featureFlags:
            (data.feature_flags as Record<string, boolean>) ?? {},
          configVersion: Number(data.config_version ?? 1),
          source: 'supabase',
        };
      }
    }

    return {
      environment: targetEnv,
      minSupportedVersion:
        this.configService.get<string>('MIN_SUPPORTED_MOBILE_VERSION') ??
        '1.0.0',
      latestVersion:
        this.configService.get<string>('APP_VERSION') ?? '1.0.0',
      maintenanceMode: false,
      maintenanceMessageEn: null,
      maintenanceMessageId: null,
      featureFlags: {
        publicQuotesEnabled: true,
        publicContentEnabled: true,
        mediaDownloadsEnabled: true,
        cloudBackupEnabled: false,
        cloudSyncEnabled: false,
      },
      configVersion: 1,
      source: 'env_default',
    };
  }
}
