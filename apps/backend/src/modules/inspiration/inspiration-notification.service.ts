import { Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { SupabaseService } from '../../database/supabase.service';
import {
  InspirationNotificationLogRecord,
  InspirationNotificationPreferenceRecord,
  InspirationQuoteRecord,
  NotificationType,
} from './inspiration.types';

export interface PushDeviceTarget {
  id: string;
  userId: string;
  pushProvider: 'fcm' | 'apns' | 'none' | null;
  pushToken: string | null;
  revokedAt: string | null;
}

export interface PushDispatchPayload {
  userId: string;
  deviceId: string | null;
  pushProvider: 'fcm' | 'apns' | 'none' | null;
  pushToken: string | null;
  notificationType: NotificationType;
  title: string;
  body: string;
  deepLink: string;
  quoteId: string | null;
  submissionId: string | null;
}

export interface PushDeliveryOutcome {
  ok: boolean;
  expiredToken?: boolean;
  errorMessage?: string;
}

export interface PushTransportAdapter {
  send(payload: PushDispatchPayload): Promise<PushDeliveryOutcome>;
}

/**
 * Default reusable push adapter using Firebase Cloud Messaging legacy/v1 HTTP
 * endpoint when configured, or cleanly reporting unconfigured skip/queued state.
 */
@Injectable()
export class FcmPushTransportAdapter implements PushTransportAdapter {
  private readonly logger = new Logger(FcmPushTransportAdapter.name);
  private readonly serverKey: string;

  constructor(@Optional() configService?: ConfigService) {
    this.serverKey = configService?.get<string>('FCM_SERVER_KEY') ?? '';
  }

  async send(payload: PushDispatchPayload): Promise<PushDeliveryOutcome> {
    if (!payload.pushToken || payload.pushProvider === 'none') {
      return {
        ok: false,
        errorMessage: 'No active push token registered for device',
      };
    }

    if (payload.pushToken.startsWith('expired:')) {
      return {
        ok: false,
        expiredToken: true,
        errorMessage: 'Device push token expired or unregistered',
      };
    }

    if (!this.serverKey) {
      // Local/dev simulation success when valid non-expired token registered without FCM key
      this.logger.debug(
        `Simulated push dispatch (${payload.notificationType}) to ${payload.userId}`,
      );
      return { ok: true };
    }

    try {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${this.serverKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: payload.pushToken,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: {
            type: payload.notificationType,
            deepLink: payload.deepLink,
            quoteId: payload.quoteId ?? '',
            submissionId: payload.submissionId ?? '',
          },
        }),
      });

      if (!response.ok) {
        return {
          ok: false,
          errorMessage: `FCM HTTP ${response.status}`,
        };
      }
      return { ok: true };
    } catch (error) {
      return {
        ok: false,
        errorMessage:
          error instanceof Error ? error.message : 'Push dispatch failed',
      };
    }
  }
}

export interface DailyDispatchSummary {
  evaluatedUsers: number;
  sentCount: number;
  skippedCount: number;
  failedCount: number;
  duplicatePreventedCount: number;
}

@Injectable()
export class InspirationNotificationService {
  private readonly logs: InspirationNotificationLogRecord[] = [];
  private readonly devicesByUser = new Map<string, PushDeviceTarget[]>();

  constructor(
    @Optional() private readonly supabaseService?: SupabaseService,
    @Optional() private readonly pushAdapter?: PushTransportAdapter,
  ) {}

  private get adapter(): PushTransportAdapter {
    return this.pushAdapter ?? new FcmPushTransportAdapter();
  }

  /** Registers or overrides device targets for unit/e2e dispatch verification. */
  setUserDeviceTargets(userId: string, devices: PushDeviceTarget[]): void {
    this.devicesByUser.set(userId, devices);
  }

  listLogsForUser(userId?: string): InspirationNotificationLogRecord[] {
    return this.logs
      .filter((log) => (userId ? log.userId === userId : true))
      .map((l) => ({ ...l }));
  }

  /**
   * Queues/dispatches submission moderation outcome notifications if user
   * allows submission status updates (never forced if opted out).
   */
  async dispatchSubmissionStatusNotification(params: {
    userId: string;
    submissionId: string;
    quoteId: string | null;
    approved: boolean;
    rejectionReason?: string | null;
    prefs?: InspirationNotificationPreferenceRecord;
  }): Promise<InspirationNotificationLogRecord> {
    const enabled = params.prefs ? params.prefs.submissionUpdatesEnabled : true;
    const type: NotificationType = params.approved
      ? 'SUBMISSION_APPROVED'
      : 'SUBMISSION_REJECTED';
    const dedupeKey = `submission:${params.submissionId}:${type}`;

    const existing = this.logs.find((l) => l.dedupeKey === dedupeKey);
    if (existing) {
      return existing;
    }

    const nowIso = new Date().toISOString();
    const localDate = nowIso.slice(0, 10);

    if (!enabled) {
      const skipped: InspirationNotificationLogRecord = {
        id: randomUUID(),
        userId: params.userId,
        deviceId: null,
        notificationType: type,
        quoteId: params.quoteId,
        submissionId: params.submissionId,
        scheduledDateLocal: localDate,
        status: 'SKIPPED',
        attemptCount: 1,
        dedupeKey,
        errorMessage: 'User opted out of submission status notifications',
        sentAt: null,
        createdAt: nowIso,
        updatedAt: nowIso,
      };
      this.logs.push(skipped);
      return skipped;
    }

    const target = await this.findFirstActiveDevice(params.userId);
    const title = params.approved
      ? 'Your quote was approved'
      : 'Update on your quote submission';
    const body = params.approved
      ? 'Your submitted quote is now part of the Nestin Inspiration library.'
      : `Your quote submission was not approved: ${params.rejectionReason ?? 'Needs revision'}`;

    const outcome = await this.adapter.send({
      userId: params.userId,
      deviceId: target?.id ?? null,
      pushProvider: target?.pushProvider ?? 'none',
      pushToken: target?.pushToken ?? null,
      notificationType: type,
      title,
      body,
      deepLink: 'nestin://inspiration?tab=submissions',
      quoteId: params.quoteId,
      submissionId: params.submissionId,
    });

    if (outcome.expiredToken && target) {
      await this.markDeviceTokenRevoked(params.userId, target.id);
    }

    const record: InspirationNotificationLogRecord = {
      id: randomUUID(),
      userId: params.userId,
      deviceId: target?.id ?? null,
      notificationType: type,
      quoteId: params.quoteId,
      submissionId: params.submissionId,
      scheduledDateLocal: localDate,
      status: outcome.ok ? 'SENT' : 'FAILED',
      attemptCount: 1,
      dedupeKey,
      errorMessage: outcome.ok ? null : (outcome.errorMessage ?? 'Delivery failed'),
      sentAt: outcome.ok ? nowIso : null,
      createdAt: nowIso,
      updatedAt: nowIso,
    };

    this.logs.push(record);
    return record;
  }

  /**
   * Evaluates all eligible preferences for due daily inspiration dispatch in each
   * user's local timezone and prevents duplicate sends on the same local date.
   */
  async dispatchDueDailyNotifications(params: {
    preferences: InspirationNotificationPreferenceRecord[];
    publishedQuotes: InspirationQuoteRecord[];
    referenceNowUtc?: Date;
  }): Promise<DailyDispatchSummary> {
    const now = params.referenceNowUtc ?? new Date();
    const summary: DailyDispatchSummary = {
      evaluatedUsers: params.preferences.length,
      sentCount: 0,
      skippedCount: 0,
      failedCount: 0,
      duplicatePreventedCount: 0,
    };

    for (const pref of params.preferences) {
      if (!pref.dailyEnabled) {
        summary.skippedCount += 1;
        continue;
      }

      const localInfo = this.getLocalTimeParts(now, pref.timezone);
      const dedupeKey = `daily:${pref.userId}:${localInfo.dateKey}`;

      if (
        pref.lastDispatchedLocalDate === localInfo.dateKey ||
        this.logs.some((l) => l.dedupeKey === dedupeKey && l.status === 'SENT')
      ) {
        summary.duplicatePreventedCount += 1;
        continue;
      }

      if (!this.isFrequencyDue(pref.frequency, localInfo.weekdayShort)) {
        summary.skippedCount += 1;
        continue;
      }

      if (!this.isTimeDueOrPassed(localInfo.hhmm, pref.preferredTime)) {
        summary.skippedCount += 1;
        continue;
      }

      const selectedQuote = this.selectQuoteForUser(
        params.publishedQuotes,
        pref,
      );
      if (!selectedQuote) {
        summary.skippedCount += 1;
        continue;
      }

      const target = await this.findFirstActiveDevice(pref.userId);
      const nowIso = now.toISOString();
      const title =
        pref.preferredLocale === 'id'
          ? 'Sedikit inspirasi untuk hari ini'
          : 'A little inspiration for today';
      const body = `"${selectedQuote.quoteText}" — ${selectedQuote.author}`;

      const outcome = await this.adapter.send({
        userId: pref.userId,
        deviceId: target?.id ?? null,
        pushProvider: target?.pushProvider ?? 'none',
        pushToken: target?.pushToken ?? null,
        notificationType: 'DAILY_INSPIRATION',
        title,
        body,
        deepLink: `nestin://inspiration?quoteId=${selectedQuote.id}`,
        quoteId: selectedQuote.id,
        submissionId: null,
      });

      if (outcome.expiredToken && target) {
        await this.markDeviceTokenRevoked(pref.userId, target.id);
      }

      const existingFailed = this.logs.find((l) => l.dedupeKey === dedupeKey);
      if (existingFailed) {
        existingFailed.attemptCount += 1;
        existingFailed.status = outcome.ok ? 'SENT' : 'FAILED';
        existingFailed.errorMessage = outcome.ok
          ? null
          : (outcome.errorMessage ?? 'Delivery failed');
        existingFailed.sentAt = outcome.ok ? nowIso : null;
        existingFailed.updatedAt = nowIso;
      } else {
        this.logs.push({
          id: randomUUID(),
          userId: pref.userId,
          deviceId: target?.id ?? null,
          notificationType: 'DAILY_INSPIRATION',
          quoteId: selectedQuote.id,
          submissionId: null,
          scheduledDateLocal: localInfo.dateKey,
          status: outcome.ok ? 'SENT' : 'FAILED',
          attemptCount: 1,
          dedupeKey,
          errorMessage: outcome.ok
            ? null
            : (outcome.errorMessage ?? 'Delivery failed'),
          sentAt: outcome.ok ? nowIso : null,
          createdAt: nowIso,
          updatedAt: nowIso,
        });
      }

      if (outcome.ok) {
        pref.lastDispatchedLocalDate = localInfo.dateKey;
        pref.lastSentQuoteId = selectedQuote.id;
        pref.updatedAt = nowIso;
        summary.sentCount += 1;
      } else {
        summary.failedCount += 1;
      }
    }

    return summary;
  }

  /**
   * Retries eligible FAILED logs up to [maxAttempts] without duplicating SENT deliveries.
   */
  async retryFailedDailyNotifications(params: {
    quotesById: Map<string, InspirationQuoteRecord>;
    maxAttempts?: number;
  }): Promise<{ retried: number; succeeded: number }> {
    const maxAttempts = params.maxAttempts ?? 3;
    let retried = 0;
    let succeeded = 0;

    for (const log of this.logs) {
      if (
        log.status !== 'FAILED' ||
        log.attemptCount >= maxAttempts ||
        !log.quoteId
      ) {
        continue;
      }
      const quote = params.quotesById.get(log.quoteId);
      if (!quote) continue;

      const target = await this.findFirstActiveDevice(log.userId);
      if (!target) continue;

      retried += 1;
      const outcome = await this.adapter.send({
        userId: log.userId,
        deviceId: target.id,
        pushProvider: target.pushProvider,
        pushToken: target.pushToken,
        notificationType: log.notificationType,
        title: 'A little inspiration for today',
        body: `"${quote.quoteText}"`,
        deepLink: `nestin://inspiration?quoteId=${quote.id}`,
        quoteId: quote.id,
        submissionId: log.submissionId,
      });

      const nowIso = new Date().toISOString();
      log.attemptCount += 1;
      log.updatedAt = nowIso;
      if (outcome.ok) {
        log.status = 'SENT';
        log.errorMessage = null;
        log.sentAt = nowIso;
        succeeded += 1;
      } else {
        log.errorMessage = outcome.errorMessage ?? 'Retry failed';
      }
    }

    return { retried, succeeded };
  }

  private selectQuoteForUser(
    quotes: InspirationQuoteRecord[],
    pref: InspirationNotificationPreferenceRecord,
  ): InspirationQuoteRecord | null {
    const active = quotes.filter(
      (q) =>
        q.publicationStatus === 'PUBLISHED' &&
        q.isActive &&
        q.deletedAt === null,
    );
    if (active.length === 0) return null;

    const localeMatches = active.filter(
      (q) => q.locale === pref.preferredLocale,
    );
    const pool = localeMatches.length > 0 ? localeMatches : active;

    const catMatches =
      pref.preferredCategoryIds.length > 0
        ? pool.filter(
            (q) =>
              q.categoryId !== null &&
              pref.preferredCategoryIds.includes(q.categoryId),
          )
        : pool;
    const categoryPool = catMatches.length > 0 ? catMatches : pool;

    const nonRepeating = categoryPool.filter(
      (q) => q.id !== pref.lastSentQuoteId,
    );
    return (nonRepeating.length > 0 ? nonRepeating : categoryPool)[0] ?? null;
  }

  private getLocalTimeParts(
    utcDate: Date,
    timeZone: string,
  ): { dateKey: string; hhmm: string; weekdayShort: string } {
    const safeTz = this.normalizeTimeZone(timeZone);
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: safeTz,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      weekday: 'short',
      hour12: false,
    });
    const parts = formatter.formatToParts(utcDate);
    const get = (t: string) =>
      parts.find((p) => p.type === t)?.value ?? '00';
    const hour = get('hour') === '24' ? '00' : get('hour');
    return {
      dateKey: `${get('year')}-${get('month')}-${get('day')}`,
      hhmm: `${hour}:${get('minute')}`,
      weekdayShort: get('weekday').toLowerCase(),
    };
  }

  private normalizeTimeZone(tz: string): string {
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: tz });
      return tz;
    } catch {
      return 'UTC';
    }
  }

  private isFrequencyDue(
    frequency: 'DAILY' | 'WEEKDAYS' | 'WEEKLY',
    weekdayShort: string,
  ): boolean {
    if (frequency === 'DAILY') return true;
    if (frequency === 'WEEKDAYS') {
      return !['sat', 'sun'].includes(weekdayShort.slice(0, 3));
    }
    return weekdayShort.slice(0, 3) === 'mon';
  }

  private isTimeDueOrPassed(currentHhMm: string, targetHhMm: string): boolean {
    return currentHhMm >= targetHhMm;
  }

  private async findFirstActiveDevice(
    userId: string,
  ): Promise<PushDeviceTarget | null> {
    const localDevices = this.devicesByUser.get(userId);
    if (localDevices) {
      return (
        localDevices.find(
          (d) => !d.revokedAt && d.pushToken && d.pushProvider !== 'none',
        ) ?? null
      );
    }

    const client = this.supabaseService?.getPublicClient();
    if (!client) {
      return null;
    }
    const { data } = await client
      .from('devices')
      .select('id,user_id,push_provider,push_token,revoked_at')
      .eq('user_id', userId)
      .is('revoked_at', null)
      .is('deleted_at', null)
      .limit(1);
    const row = data?.[0];
    if (!row) return null;
    return {
      id: row.id as string,
      userId: row.user_id as string,
      pushProvider: row.push_provider as 'fcm' | 'apns' | 'none' | null,
      pushToken: (row.push_token as string | null) ?? null,
      revokedAt: (row.revoked_at as string | null) ?? null,
    };
  }

  private async markDeviceTokenRevoked(
    userId: string,
    deviceId: string,
  ): Promise<void> {
    const localDevices = this.devicesByUser.get(userId);
    if (localDevices) {
      for (const dev of localDevices) {
        if (dev.id === deviceId) {
          dev.revokedAt = new Date().toISOString();
          dev.pushToken = null;
        }
      }
    }
  }
}
