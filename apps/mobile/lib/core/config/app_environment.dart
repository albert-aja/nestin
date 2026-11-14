/// Compile-time environment configuration for optional Nestin backend & Supabase
/// services.
///
/// SECURITY BOUNDARY:
/// Never place `SUPABASE_SERVICE_ROLE_KEY` in mobile `--dart-define` values or
/// client bundles. Only public endpoints and the Supabase `anon` key belong here.
class AppEnvironment {
  static const String environment = String.fromEnvironment(
    'NESTIN_ENV',
    defaultValue: 'local_offline',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'NESTIN_API_BASE_URL',
    defaultValue: '',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'NESTIN_SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'NESTIN_SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isBackendConfigured => apiBaseUrl.trim().isNotEmpty;

  static bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static Uri? buildApiUri(
    String v1Path, [
    Map<String, String>? queryParameters,
  ]) {
    final trimmed = apiBaseUrl.trim().replaceAll(RegExp(r'/*$'), '');
    if (trimmed.isEmpty) return null;
    final normalizedPath =
        v1Path.startsWith('/') ? v1Path : '/$v1Path';
    final uri = Uri.parse('$trimmed/api/v1$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  static Uri? buildSupabaseAuthUri(
    String authPath, [
    Map<String, String>? queryParameters,
  ]) {
    final trimmed = supabaseUrl.trim().replaceAll(RegExp(r'/*$'), '');
    if (trimmed.isEmpty || supabaseAnonKey.trim().isEmpty) return null;
    final normalizedPath =
        authPath.startsWith('/') ? authPath : '/$authPath';
    final uri = Uri.parse('$trimmed/auth/v1$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }
}
