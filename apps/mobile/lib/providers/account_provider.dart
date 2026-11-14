import 'package:flutter/foundation.dart';
import '../core/config/api_contracts.dart';
import '../data/services/backend_gateway_service.dart';
import '../data/services/storage_service.dart';

/// Optional local-first account & guest migration state provider.
///
/// Nestin operates completely without an account; this provider only tracks an
/// optional Supabase Auth session and the `POST /api/v1/auth/guest-migration/prepare`
/// linkage handshake while preserving every local record on-device.
class AccountProvider extends ChangeNotifier {
  final StorageService _storageService;
  final BackendGatewayService _gateway;

  bool _isInitialized = false;
  bool _isSubmitting = false;
  bool _isDisposed = false;
  GuestIdentityProfile? _guestIdentity;
  SupabaseAuthSession? _session;
  GuestMigrationReceipt? _lastMigrationReceipt;
  String? _lastErrorMessage;
  String? _pendingConfirmationEmail;

  AccountProvider(
    this._storageService, {
    BackendGatewayService? gateway,
  }) : _gateway = gateway ?? BackendGatewayService(_storageService.prefs) {
    _session = _gateway.loadStoredAuthSession();
    _lastMigrationReceipt = _gateway.loadLastMigrationReceipt();
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  bool get isInitialized => _isInitialized;
  bool get isSubmitting => _isSubmitting;
  GuestIdentityProfile? get guestIdentity => _guestIdentity;
  SupabaseAuthSession? get session => _session;
  GuestMigrationReceipt? get lastMigrationReceipt => _lastMigrationReceipt;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get pendingConfirmationEmail => _pendingConfirmationEmail;

  bool get isSignedIn => _session != null && !_session!.isExpired;
  bool get isGuestLinked =>
      _guestIdentity?.authMode == AccountAuthMode.registered &&
      (_guestIdentity?.linkedUserId?.isNotEmpty ?? false);
  bool get isSupabaseConfigured => _gateway.isSupabaseConfigured;
  bool get isBackendConfigured => _gateway.isBackendConfigured;

  Map<String, int> get localRecordCounts =>
      _storageService.collectLocalRecordCounts();

  int get totalLocalRecordCount =>
      localRecordCounts.values.fold<int>(0, (sum, count) => sum + count);

  Future<void> initialize() async {
    _guestIdentity = await _gateway.ensureGuestIdentity();
    _session = _gateway.loadStoredAuthSession();
    _lastMigrationReceipt = _gateway.loadLastMigrationReceipt();
    _isInitialized = true;
    _safeNotify();
  }

  void clearMessages() {
    if (_lastErrorMessage == null && _pendingConfirmationEmail == null) return;
    _lastErrorMessage = null;
    _pendingConfirmationEmail = null;
    _safeNotify();
  }

  /// Signs up via Supabase Auth and, when a live session is returned and the
  /// backend is configured, optionally prepares guest-to-registered migration
  /// without touching local Nestin records.
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
    String preferredLanguage = 'en',
    bool prepareMigrationOnSuccess = true,
  }) async {
    _isSubmitting = true;
    _lastErrorMessage = null;
    _pendingConfirmationEmail = null;
    _safeNotify();

    try {
      _guestIdentity ??= await _gateway.ensureGuestIdentity();
      final result = await _gateway.signUpWithSupabase(
        email: email,
        password: password,
        displayName: displayName,
        preferredLanguage: preferredLanguage,
      );

      if (!result.isSuccess || result.data == null) {
        _lastErrorMessage = result.errorMessage ?? 'Unable to create account.';
        return false;
      }

      final outcome = result.data!;
      if (outcome.requiresEmailConfirmation || outcome.session == null) {
        _pendingConfirmationEmail = outcome.pendingEmail ?? email.trim();
        return true;
      }

      _session = outcome.session;
      if (prepareMigrationOnSuccess && _gateway.isBackendConfigured) {
        final migrationResult = await _gateway.prepareGuestMigration(
          preferredLanguage: preferredLanguage,
          localRecordCounts: _storageService.collectLocalRecordCounts(),
          accessTokenOverride: _session!.accessToken,
        );
        if (migrationResult.isSuccess && migrationResult.data != null) {
          _lastMigrationReceipt = migrationResult.data;
          _guestIdentity = await _gateway.ensureGuestIdentity();
        } else {
          // Account creation succeeded cleanly even if backend link call failed.
          _lastErrorMessage = migrationResult.errorMessage;
        }
      }
      return true;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  /// Signs into an existing Supabase Auth account and optionally prepares
  /// guest migration without mutating local Nestin records.
  Future<bool> signIn({
    required String email,
    required String password,
    String preferredLanguage = 'en',
    bool prepareMigrationOnSuccess = false,
  }) async {
    _isSubmitting = true;
    _lastErrorMessage = null;
    _pendingConfirmationEmail = null;
    _safeNotify();

    try {
      _guestIdentity ??= await _gateway.ensureGuestIdentity();
      final result = await _gateway.signInWithSupabase(
        email: email,
        password: password,
      );

      if (!result.isSuccess || result.data == null) {
        _lastErrorMessage = result.errorMessage ?? 'Unable to sign in.';
        return false;
      }

      _session = result.data;
      if (prepareMigrationOnSuccess && _gateway.isBackendConfigured) {
        final migrationResult = await _gateway.prepareGuestMigration(
          preferredLanguage: preferredLanguage,
          localRecordCounts: _storageService.collectLocalRecordCounts(),
          accessTokenOverride: _session!.accessToken,
        );
        if (migrationResult.isSuccess && migrationResult.data != null) {
          _lastMigrationReceipt = migrationResult.data;
          _guestIdentity = await _gateway.ensureGuestIdentity();
        } else {
          _lastErrorMessage = migrationResult.errorMessage;
        }
      }
      return true;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  /// Triggers `POST /api/v1/auth/guest-migration/prepare` for the active session
  /// and device `guestLocalId`, strictly preserving all local data on-device.
  Future<BackendResult<GuestMigrationReceipt>> prepareGuestMigration({
    String preferredLanguage = 'en',
  }) async {
    _isSubmitting = true;
    _lastErrorMessage = null;
    _safeNotify();

    try {
      _guestIdentity ??= await _gateway.ensureGuestIdentity();
      final result = await _gateway.prepareGuestMigration(
        preferredLanguage: preferredLanguage,
        localRecordCounts: _storageService.collectLocalRecordCounts(),
        accessTokenOverride: _session?.accessToken,
      );

      if (result.isSuccess && result.data != null) {
        _lastMigrationReceipt = result.data;
        _guestIdentity = await _gateway.ensureGuestIdentity();
      } else {
        _lastErrorMessage =
            result.errorMessage ?? 'Unable to prepare guest migration.';
      }
      return result;
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }

  /// Signs out cleanly while retaining the local guest UUID and every local record.
  Future<void> signOut() async {
    _isSubmitting = true;
    _lastErrorMessage = null;
    _pendingConfirmationEmail = null;
    _safeNotify();

    try {
      await _gateway.signOut();
      _session = null;
      _guestIdentity = await _gateway.ensureGuestIdentity();
    } finally {
      _isSubmitting = false;
      _safeNotify();
    }
  }
}
