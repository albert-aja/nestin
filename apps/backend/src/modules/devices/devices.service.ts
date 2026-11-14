import {
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { AuthenticatedUser } from '../../common/decorators/current-user.decorator';
import { SupabaseService } from '../../database/supabase.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

interface DeviceRow {
  id: string;
  user_id: string;
  device_identifier: string;
  platform: string;
  device_name: string | null;
  os_version: string | null;
  app_version: string | null;
  push_provider: string | null;
  last_seen_at: string;
  revoked_at: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

@Injectable()
export class DevicesService {
  constructor(private readonly supabaseService: SupabaseService) {}

  async listDevices(user: AuthenticatedUser) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase device registry is not configured on this server',
      );
    }

    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const { data, error } = await client
      .from('devices')
      .select(
        'id,user_id,device_identifier,platform,device_name,os_version,app_version,push_provider,last_seen_at,revoked_at,created_at,updated_at,deleted_at',
      )
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .order('last_seen_at', { ascending: false })
      .returns<DeviceRow[]>();

    if (error) {
      throw new ServiceUnavailableException(error.message);
    }
    return (data ?? []).map((row) => this.toContract(row));
  }

  async registerOrUpdateDevice(
    user: AuthenticatedUser,
    dto: RegisterDeviceDto,
  ) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase device registry is not configured on this server',
      );
    }

    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const nowIso = new Date().toISOString();

    const { data, error } = await client
      .from('devices')
      .upsert(
        {
          user_id: user.id,
          device_identifier: dto.deviceIdentifier,
          platform: dto.platform,
          device_name: dto.deviceName ?? null,
          os_version: dto.osVersion ?? null,
          app_version: dto.appVersion ?? null,
          push_token: dto.pushToken ?? null,
          push_provider: dto.pushProvider ?? 'none',
          last_seen_at: nowIso,
          revoked_at: null,
          deleted_at: null,
        },
        { onConflict: 'user_id,device_identifier' },
      )
      .select(
        'id,user_id,device_identifier,platform,device_name,os_version,app_version,push_provider,last_seen_at,revoked_at,created_at,updated_at,deleted_at',
      )
      .single<DeviceRow>();

    if (error || !data) {
      throw new ServiceUnavailableException(
        error?.message ?? 'Failed to register device',
      );
    }
    return this.toContract(data);
  }

  async revokeDevice(user: AuthenticatedUser, deviceId: string) {
    if (!this.supabaseService.isConfigured) {
      throw new ServiceUnavailableException(
        'Supabase device registry is not configured on this server',
      );
    }

    const nowIso = new Date().toISOString();
    const client = this.supabaseService.createUserScopedClient(
      user.accessToken,
    );
    const { data, error } = await client
      .from('devices')
      .update({
        revoked_at: nowIso,
        deleted_at: nowIso,
        push_token: null,
      })
      .eq('id', deviceId)
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .select('id')
      .maybeSingle();

    if (error) {
      throw new ServiceUnavailableException(error.message);
    }
    if (!data) {
      throw new NotFoundException('Registered device not found');
    }
    return {
      deviceId,
      revokedAt: nowIso,
    };
  }

  private toContract(row: DeviceRow) {
    return {
      id: row.id,
      userId: row.user_id,
      deviceIdentifier: row.device_identifier,
      platform: row.platform,
      deviceName: row.device_name,
      osVersion: row.os_version,
      appVersion: row.app_version,
      pushProvider: row.push_provider,
      lastSeenAt: row.last_seen_at,
      revokedAt: row.revoked_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      deletedAt: row.deleted_at,
    };
  }
}
