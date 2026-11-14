/// Mirrors `packages/contracts/api.types.ts` for future guest-to-account
/// linking and P1 incremental synchronization without disrupting local storage.
enum SyncStatus {
  localOnly,
  pendingPush,
  synced,
  conflict,
}

enum AccountAuthMode {
  guest,
  registered,
}

/// Optional synchronization metadata envelope compatible with future tombstones
/// and soft deletion (`id`, `createdAt`, `updatedAt`, `deletedAt`).
class SyncMetadata {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final SyncStatus syncStatus;

  const SyncMetadata({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.syncStatus = SyncStatus.localOnly,
  });

  bool get isDeleted => deletedAt != null;

  SyncMetadata markUpdated({DateTime? now}) {
    final ts = (now ?? DateTime.now()).toUtc();
    return SyncMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: ts,
      deletedAt: deletedAt,
      syncStatus: syncStatus == SyncStatus.synced
          ? SyncStatus.pendingPush
          : syncStatus,
    );
  }

  SyncMetadata markDeleted({DateTime? now}) {
    final ts = (now ?? DateTime.now()).toUtc();
    return SyncMetadata(
      id: id,
      createdAt: createdAt,
      updatedAt: ts,
      deletedAt: ts,
      syncStatus: SyncStatus.pendingPush,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'deletedAt': deletedAt?.toUtc().toIso8601String(),
      'syncStatus': syncStatus.name,
    };
  }

  factory SyncMetadata.fromJson(Map<String, dynamic> json) {
    final statusName = json['syncStatus'] as String?;
    final status = SyncStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => SyncStatus.localOnly,
    );
    return SyncMetadata(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'] as String)
          : null,
      syncStatus: status,
    );
  }
}

/// Automatically provisioned on-device guest identity so users never need to
/// register before using Nestin. Preserved across future guest->account migration.
class GuestIdentityProfile {
  final String guestLocalId;
  final AccountAuthMode authMode;
  final String? linkedUserId;
  final bool cloudSyncOptIn;
  final DateTime createdAt;
  final DateTime? migratedFromGuestAt;

  const GuestIdentityProfile({
    required this.guestLocalId,
    this.authMode = AccountAuthMode.guest,
    this.linkedUserId,
    this.cloudSyncOptIn = false,
    required this.createdAt,
    this.migratedFromGuestAt,
  });

  GuestIdentityProfile linkRegisteredAccount({
    required String userId,
    bool optInCloudSync = false,
    DateTime? migratedAt,
  }) {
    return GuestIdentityProfile(
      guestLocalId: guestLocalId,
      authMode: AccountAuthMode.registered,
      linkedUserId: userId,
      cloudSyncOptIn: optInCloudSync,
      createdAt: createdAt,
      migratedFromGuestAt: migratedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Reverts auth linkage metadata to local guest posture while keeping
  /// [guestLocalId] and all on-device operational data completely intact.
  GuestIdentityProfile resetToGuest() {
    return GuestIdentityProfile(
      guestLocalId: guestLocalId,
      authMode: AccountAuthMode.guest,
      linkedUserId: null,
      cloudSyncOptIn: false,
      createdAt: createdAt,
      migratedFromGuestAt: migratedFromGuestAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guestLocalId': guestLocalId,
      'authMode': authMode.name,
      'linkedUserId': linkedUserId,
      'cloudSyncOptIn': cloudSyncOptIn,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'migratedFromGuestAt': migratedFromGuestAt?.toUtc().toIso8601String(),
    };
  }

  factory GuestIdentityProfile.fromJson(Map<String, dynamic> json) {
    final modeName = json['authMode'] as String?;
    final mode = AccountAuthMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => AccountAuthMode.guest,
    );
    return GuestIdentityProfile(
      guestLocalId: json['guestLocalId'] as String,
      authMode: mode,
      linkedUserId: json['linkedUserId'] as String?,
      cloudSyncOptIn: json['cloudSyncOptIn'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      migratedFromGuestAt: json['migratedFromGuestAt'] != null
          ? DateTime.parse(json['migratedFromGuestAt'] as String)
          : null,
    );
  }
}

/// Optional Supabase Auth session held locally on-device.
class SupabaseAuthSession {
  final String accessToken;
  final String? refreshToken;
  final String userId;
  final String? email;
  final String? displayName;
  final DateTime? expiresAt;

  const SupabaseAuthSession({
    required this.accessToken,
    required this.userId,
    this.refreshToken,
    this.email,
    this.displayName,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };

  factory SupabaseAuthSession.fromJson(Map<String, dynamic> json) {
    return SupabaseAuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// Result returned by Supabase Auth `/auth/v1/signup`.
class SupabaseSignUpOutcome {
  final SupabaseAuthSession? session;
  final String? userId;
  final String? pendingEmail;
  final bool requiresEmailConfirmation;

  const SupabaseSignUpOutcome({
    this.session,
    this.userId,
    this.pendingEmail,
    this.requiresEmailConfirmation = false,
  });
}

/// Server acknowledgement from `POST /api/v1/auth/guest-migration/prepare`.
class GuestMigrationReceipt {
  final String userId;
  final String guestLocalId;
  final DateTime migratedAt;
  final bool localDataPreserved;
  final bool cloudSyncOptIn;
  final Map<String, int> acknowledgedLocalCounts;

  const GuestMigrationReceipt({
    required this.userId,
    required this.guestLocalId,
    required this.migratedAt,
    required this.localDataPreserved,
    required this.cloudSyncOptIn,
    this.acknowledgedLocalCounts = const {},
  });

  int get totalAcknowledgedCount =>
      acknowledgedLocalCounts.values.fold<int>(0, (sum, count) => sum + count);

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'guestLocalId': guestLocalId,
        'migratedAt': migratedAt.toUtc().toIso8601String(),
        'localDataPreserved': localDataPreserved,
        'cloudSyncOptIn': cloudSyncOptIn,
        'acknowledgedLocalCounts': acknowledgedLocalCounts,
      };

  factory GuestMigrationReceipt.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['acknowledgedLocalCounts'];
    final parsedCounts = <String, int>{};
    if (rawCounts is Map) {
      rawCounts.forEach((key, value) {
        if (value is num) {
          parsedCounts[key.toString()] = value.toInt();
        }
      });
    }
    return GuestMigrationReceipt(
      userId: json['userId'] as String? ?? '',
      guestLocalId: json['guestLocalId'] as String? ?? '',
      migratedAt: json['migratedAt'] != null
          ? (DateTime.tryParse(json['migratedAt'] as String) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      localDataPreserved: json['localDataPreserved'] as bool? ?? true,
      cloudSyncOptIn: json['cloudSyncOptIn'] as bool? ?? false,
      acknowledgedLocalCounts: parsedCounts,
    );
  }
}
