import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/api_contracts.dart';
import '../../core/config/app_environment.dart';

class BackendResult<T> {
  final bool isSuccess;
  final bool isOfflineOrUnconfigured;
  final T? data;
  final String? errorMessage;

  const BackendResult._({
    required this.isSuccess,
    required this.isOfflineOrUnconfigured,
    this.data,
    this.errorMessage,
  });

  factory BackendResult.ok(T data) => BackendResult._(
        isSuccess: true,
        isOfflineOrUnconfigured: false,
        data: data,
      );

  factory BackendResult.offline(String reason) => BackendResult._(
        isSuccess: false,
        isOfflineOrUnconfigured: true,
        errorMessage: reason,
      );

  factory BackendResult.error(String message) => BackendResult._(
        isSuccess: false,
        isOfflineOrUnconfigured: false,
        errorMessage: message,
      );
}

/// Runtime or compile-time endpoints used by [BackendGatewayService].
class BackendGatewayConfig {
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const BackendGatewayConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory BackendGatewayConfig.fromEnvironment() => const BackendGatewayConfig(
        apiBaseUrl: AppEnvironment.apiBaseUrl,
        supabaseUrl: AppEnvironment.supabaseUrl,
        supabaseAnonKey: AppEnvironment.supabaseAnonKey,
      );

  bool get isBackendConfigured => apiBaseUrl.trim().isNotEmpty;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  Uri? buildApiUri(
    String v1Path, [
    Map<String, String>? queryParameters,
  ]) {
    final trimmed = apiBaseUrl.trim().replaceAll(RegExp(r'/*$'), '');
    if (trimmed.isEmpty) return null;
    final normalizedPath = v1Path.startsWith('/') ? v1Path : '/$v1Path';
    final uri = Uri.parse('$trimmed/api/v1$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Uri? buildSupabaseAuthUri(
    String authPath, [
    Map<String, String>? queryParameters,
  ]) {
    final trimmed = supabaseUrl.trim().replaceAll(RegExp(r'/*$'), '');
    if (trimmed.isEmpty || supabaseAnonKey.trim().isEmpty) return null;
    final normalizedPath = authPath.startsWith('/') ? authPath : '/$authPath';
    final uri = Uri.parse('$trimmed/auth/v1$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }
}

class BackendHttpResponse {
  final int statusCode;
  final String body;

  const BackendHttpResponse({
    required this.statusCode,
    required this.body,
  });
}

/// Minimal HTTP transport abstraction so network I/O stays dependency-free
/// (`dart:io`) while remaining deterministic to test without live sockets.
abstract class BackendHttpTransport {
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  });
}

class _DartIoBackendHttpTransport implements BackendHttpTransport {
  const _DartIoBackendHttpTransport();

  @override
  Future<BackendHttpResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.openUrl(method, uri).timeout(timeout);
      headers.forEach((key, value) {
        req.headers.set(key, value);
      });
      if (body != null) {
        req.add(utf8.encode(body));
      }
      final res = await req.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(res).join();
      return BackendHttpResponse(
        statusCode: res.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// Optional companion gateway connecting the local-first mobile app to
/// Supabase Auth and `/api/v1` backend capabilities without ever modifying or
/// risking on-device Nestin records.
class BackendGatewayService {
  static const String _keyGuestIdentity = 'nestin_guest_identity_v1';
  static const String _keyAuthSession = 'nestin_auth_session_v1';
  static const String _keyMigrationReceipt =
      'nestin_guest_migration_receipt_v1';

  final SharedPreferences _prefs;
  final Uuid _uuid;
  final BackendGatewayConfig _config;
  final BackendHttpTransport _transport;

  BackendGatewayService(
    this._prefs, {
    Uuid? uuid,
    BackendGatewayConfig? config,
    BackendHttpTransport? transport,
  })  : _uuid = uuid ?? const Uuid(),
        _config = config ?? BackendGatewayConfig.fromEnvironment(),
        _transport = transport ?? const _DartIoBackendHttpTransport();

  bool get isBackendConfigured => _config.isBackendConfigured;
  bool get isSupabaseConfigured => _config.isSupabaseConfigured;

  /// Automatically provisions a persistent UUID-backed local guest profile
  /// so Nestin works seamlessly with zero registration.
  Future<GuestIdentityProfile> ensureGuestIdentity() async {
    final raw = _prefs.getString(_keyGuestIdentity);
    if (raw != null && raw.isNotEmpty) {
      try {
        return GuestIdentityProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        // Fall through to re-seed cleanly if corrupted
      }
    }

    final created = GuestIdentityProfile(
      guestLocalId: _uuid.v4(),
      authMode: AccountAuthMode.guest,
      cloudSyncOptIn: false,
      createdAt: DateTime.now().toUtc(),
    );
    await saveGuestIdentity(created);
    return created;
  }

  Future<void> saveGuestIdentity(GuestIdentityProfile profile) async {
    await _prefs.setString(_keyGuestIdentity, jsonEncode(profile.toJson()));
  }

  SupabaseAuthSession? loadStoredAuthSession() {
    final raw = _prefs.getString(_keyAuthSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SupabaseAuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAuthSession(SupabaseAuthSession? session) async {
    if (session == null) {
      await _prefs.remove(_keyAuthSession);
      return;
    }
    await _prefs.setString(_keyAuthSession, jsonEncode(session.toJson()));
  }

  GuestMigrationReceipt? loadLastMigrationReceipt() {
    final raw = _prefs.getString(_keyMigrationReceipt);
    if (raw == null || raw.isEmpty) return null;
    try {
      return GuestMigrationReceipt.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMigrationReceipt(GuestMigrationReceipt? receipt) async {
    if (receipt == null) {
      await _prefs.remove(_keyMigrationReceipt);
      return;
    }
    await _prefs.setString(_keyMigrationReceipt, jsonEncode(receipt.toJson()));
  }

  /// Registers an optional Supabase Auth email/password account without touching
  /// any local Nestin records on-device.
  Future<BackendResult<SupabaseSignUpOutcome>> signUpWithSupabase({
    required String email,
    required String password,
    String? displayName,
    String preferredLanguage = 'en',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = _config.buildSupabaseAuthUri('/signup');
    if (uri == null) {
      return BackendResult.offline(
        'Supabase Auth is not configured in this build; operating locally.',
      );
    }

    final normalizedEmail = email.trim();
    final lang = preferredLanguage == 'id' ? 'id' : 'en';
    final trimmedName = displayName?.trim();
    final payload = <String, dynamic>{
      'email': normalizedEmail,
      'password': password,
      'data': <String, dynamic>{
        'preferred_language': lang,
        if (trimmedName != null && trimmedName.isNotEmpty)
          'display_name': trimmedName,
      },
    };

    try {
      final res = await _transport.send(
        method: 'POST',
        uri: uri,
        headers: _supabaseHeaders(),
        body: jsonEncode(payload),
        timeout: timeout,
      );
      final decoded = _tryDecodeMap(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return BackendResult.error(
          _extractErrorMessage(decoded, fallback: 'HTTP ${res.statusCode}'),
        );
      }

      final session = _parseSupabaseSession(
        decoded,
        fallbackEmail: normalizedEmail,
        fallbackDisplayName: trimmedName,
      );
      if (session != null) {
        await saveAuthSession(session);
        return BackendResult.ok(
          SupabaseSignUpOutcome(
            session: session,
            userId: session.userId,
            requiresEmailConfirmation: false,
          ),
        );
      }

      final rawUser = decoded['user'];
      final userMap = rawUser is Map<String, dynamic> ? rawUser : decoded;
      return BackendResult.ok(
        SupabaseSignUpOutcome(
          userId: userMap['id'] as String?,
          pendingEmail: userMap['email'] as String? ?? normalizedEmail,
          requiresEmailConfirmation: true,
        ),
      );
    } catch (e) {
      return BackendResult.offline(e.toString());
    }
  }

  /// Signs into an optional Supabase Auth account using email/password without
  /// modifying any local Nestin records on-device.
  Future<BackendResult<SupabaseAuthSession>> signInWithSupabase({
    required String email,
    required String password,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = _config.buildSupabaseAuthUri(
      '/token',
      {'grant_type': 'password'},
    );
    if (uri == null) {
      return BackendResult.offline(
        'Supabase Auth is not configured in this build; operating locally.',
      );
    }

    final normalizedEmail = email.trim();
    try {
      final res = await _transport.send(
        method: 'POST',
        uri: uri,
        headers: _supabaseHeaders(),
        body: jsonEncode({
          'email': normalizedEmail,
          'password': password,
        }),
        timeout: timeout,
      );
      final decoded = _tryDecodeMap(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return BackendResult.error(
          _extractErrorMessage(decoded, fallback: 'HTTP ${res.statusCode}'),
        );
      }

      final session = _parseSupabaseSession(
        decoded,
        fallbackEmail: normalizedEmail,
      );
      if (session == null) {
        return BackendResult.error('Invalid session payload returned by auth.');
      }
      await saveAuthSession(session);
      return BackendResult.ok(session);
    } catch (e) {
      return BackendResult.offline(e.toString());
    }
  }

  /// Invokes `POST /api/v1/auth/guest-migration/prepare` to link the local
  /// `guestLocalId` UUID to the authenticated Supabase user while leaving all
  /// local operational records completely untouched (`cloudSyncOptIn = false`).
  Future<BackendResult<GuestMigrationReceipt>> prepareGuestMigration({
    String preferredLanguage = 'en',
    Map<String, int>? localRecordCounts,
    String? accessTokenOverride,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = _config.buildApiUri('/auth/guest-migration/prepare');
    if (uri == null) {
      return BackendResult.offline(
        'Backend URL not configured; operating in local-first offline mode.',
      );
    }

    final token = accessTokenOverride ?? loadStoredAuthSession()?.accessToken;
    if (token == null || token.trim().isEmpty) {
      return BackendResult.error(
        'Sign in first before preparing guest account migration.',
      );
    }

    final guest = await ensureGuestIdentity();
    final lang = preferredLanguage == 'id' ? 'id' : 'en';
    final body = <String, dynamic>{
      'guestLocalId': guest.guestLocalId,
      'preferredLanguage': lang,
      'localRecordCounts': ?localRecordCounts,
    };

    try {
      final res = await _transport.send(
        method: 'POST',
        uri: uri,
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $token',
        },
        body: jsonEncode(body),
        timeout: timeout,
      );
      final decoded = _tryDecodeMap(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return BackendResult.error(
          _extractErrorMessage(decoded, fallback: 'HTTP ${res.statusCode}'),
        );
      }

      final data = decoded['data'];
      final payload = data is Map<String, dynamic> ? data : decoded;
      final receipt = GuestMigrationReceipt.fromJson(payload);

      final linkedProfile = guest.linkRegisteredAccount(
        userId: receipt.userId.isNotEmpty
            ? receipt.userId
            : (loadStoredAuthSession()?.userId ?? ''),
        optInCloudSync: receipt.cloudSyncOptIn,
        migratedAt: receipt.migratedAt,
      );
      await saveGuestIdentity(linkedProfile);
      await saveMigrationReceipt(receipt);

      return BackendResult.ok(receipt);
    } catch (e) {
      return BackendResult.offline(e.toString());
    }
  }

  /// Clears the optional cloud auth session while strictly keeping all local
  /// records and [guestLocalId] intact on-device.
  Future<void> signOut({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final existing = loadStoredAuthSession();
    final uri = _config.buildSupabaseAuthUri('/logout');
    if (uri != null && existing != null && existing.accessToken.isNotEmpty) {
      try {
        await _transport.send(
          method: 'POST',
          uri: uri,
          headers: _supabaseHeaders(bearerToken: existing.accessToken),
          timeout: timeout,
        );
      } catch (_) {
        // Local sign-out never fails if offline.
      }
    }

    await saveAuthSession(null);
    final guest = await ensureGuestIdentity();
    await saveGuestIdentity(guest.resetToGuest());
  }

  /// Fetches `/api/v1/config` without requiring auth or failing offline app usage.
  Future<BackendResult<Map<String, dynamic>>> fetchRemoteConfig({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return _getPublicJson('/config', timeout: timeout);
  }

  /// Fetches `/api/v1/quotes/featured` for optional online inspiration cards.
  Future<BackendResult<Map<String, dynamic>>> fetchFeaturedQuote({
    String locale = 'en',
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return _getPublicJson(
      '/quotes/featured',
      query: {'locale': locale},
      timeout: timeout,
    );
  }

  Future<BackendResult<Map<String, dynamic>>> _getPublicJson(
    String v1Path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final uri = _config.buildApiUri(v1Path, query);
    if (uri == null) {
      return BackendResult.offline(
        'Backend URL not configured; operating in local-first offline mode.',
      );
    }

    try {
      final res = await _transport.send(
        method: 'GET',
        uri: uri,
        headers: const {
          HttpHeaders.acceptHeader: 'application/json',
        },
        timeout: timeout,
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final decoded = _tryDecodeMap(res.body);
        return BackendResult.error(
          _extractErrorMessage(decoded, fallback: 'HTTP ${res.statusCode}'),
        );
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return BackendResult.ok(data);
      }
      return BackendResult.ok(decoded);
    } catch (e) {
      return BackendResult.offline(e.toString());
    }
  }

  Map<String, String> _supabaseHeaders({String? bearerToken}) => {
        'apikey': _config.supabaseAnonKey,
        HttpHeaders.authorizationHeader:
            'Bearer ${bearerToken ?? _config.supabaseAnonKey}',
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
      };

  SupabaseAuthSession? _parseSupabaseSession(
    Map<String, dynamic> decoded, {
    String? fallbackEmail,
    String? fallbackDisplayName,
  }) {
    final accessToken = decoded['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;

    final userMap = decoded['user'] is Map<String, dynamic>
        ? decoded['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final userId = userMap['id'] as String?;
    if (userId == null || userId.isEmpty) return null;

    final userMeta = userMap['user_metadata'] is Map<String, dynamic>
        ? userMap['user_metadata'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final expiresIn = decoded['expires_in'];
    final expiresAt = expiresIn is num
        ? DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()))
        : null;

    return SupabaseAuthSession(
      accessToken: accessToken,
      refreshToken: decoded['refresh_token'] as String?,
      userId: userId,
      email: (userMap['email'] as String?) ?? fallbackEmail,
      displayName: (userMeta['display_name'] as String?) ?? fallbackDisplayName,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> _tryDecodeMap(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  String _extractErrorMessage(
    Map<String, dynamic> decoded, {
    required String fallback,
  }) {
    final nestedError = decoded['error'];
    if (nestedError is Map<String, dynamic>) {
      final msg = nestedError['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    } else if (nestedError is String && nestedError.isNotEmpty) {
      return nestedError;
    }

    for (final key in const ['error_description', 'msg', 'message']) {
      final val = decoded[key];
      if (val is String && val.isNotEmpty) return val;
    }
    return fallback;
  }
}
