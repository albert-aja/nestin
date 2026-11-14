export type NodeEnvironment = 'development' | 'test' | 'staging' | 'production';

export interface BackendEnvConfig {
  nodeEnv: NodeEnvironment;
  port: number;
  corsOrigins: string[];
  logLevel: string;
  appVersion: string;
  minSupportedMobileVersion: string;
  throttleTtlSeconds: number;
  throttleLimit: number;
  supabaseUrl: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey: string;
  supabaseJwtSecret: string;
}

function parsePositiveInt(
  raw: unknown,
  fallback: number,
  fieldName: string,
): number {
  if (raw === undefined || raw === null || raw === '') {
    return fallback;
  }
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`Invalid environment variable ${fieldName}: must be a positive integer`);
  }
  return parsed;
}

export function validateEnv(
  raw: Record<string, unknown>,
): Record<string, unknown> {
  const nodeEnvRaw = String(raw.NODE_ENV ?? 'development').trim();
  const validEnvs: NodeEnvironment[] = [
    'development',
    'test',
    'staging',
    'production',
  ];
  const nodeEnv = validEnvs.includes(nodeEnvRaw as NodeEnvironment)
    ? (nodeEnvRaw as NodeEnvironment)
    : 'development';

  const port = parsePositiveInt(raw.PORT, 3000, 'PORT');
  const throttleTtlSeconds = parsePositiveInt(
    raw.THROTTLE_TTL_SECONDS,
    60,
    'THROTTLE_TTL_SECONDS',
  );
  const throttleLimit = parsePositiveInt(
    raw.THROTTLE_LIMIT,
    120,
    'THROTTLE_LIMIT',
  );

  const supabaseUrl = String(raw.SUPABASE_URL ?? '').trim();
  if (supabaseUrl && !/^https?:\/\/.+/.test(supabaseUrl)) {
    throw new Error('Invalid SUPABASE_URL: must start with http:// or https://');
  }

  return {
    ...raw,
    NODE_ENV: nodeEnv,
    PORT: port,
    THROTTLE_TTL_SECONDS: throttleTtlSeconds,
    THROTTLE_LIMIT: throttleLimit,
    SUPABASE_URL: supabaseUrl,
    SUPABASE_ANON_KEY: String(raw.SUPABASE_ANON_KEY ?? '').trim(),
    SUPABASE_SERVICE_ROLE_KEY: String(raw.SUPABASE_SERVICE_ROLE_KEY ?? '').trim(),
    SUPABASE_JWT_SECRET: String(raw.SUPABASE_JWT_SECRET ?? '').trim(),
    APP_VERSION: String(raw.APP_VERSION ?? '1.0.0').trim(),
    MIN_SUPPORTED_MOBILE_VERSION: String(
      raw.MIN_SUPPORTED_MOBILE_VERSION ?? '1.0.0',
    ).trim(),
    CORS_ORIGINS: String(
      raw.CORS_ORIGINS ??
        'http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173',
    ).trim(),
    LOG_LEVEL: String(raw.LOG_LEVEL ?? 'info').trim(),
  };
}
