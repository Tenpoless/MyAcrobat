import path from 'node:path';

export interface AppConfig {
  port: number;
  host: string;
  megaEmail: string;
  megaPassword: string;
  megaRootFolder: string;
  syncroDbUrl: string;
  syncroPublicStorageDir: string;
  authTokenSecret: string;
  publicWebDir: string;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const megaEmail = env.MEGA_EMAIL?.trim() ?? '';
  const megaPassword = env.MEGA_PASSWORD?.trim() ?? '';

  if (!megaEmail || !megaPassword) {
    throw new Error('Missing required Mega.nz credentials in environment: MEGA_EMAIL, MEGA_PASSWORD');
  }

  const parsedPort = Number(env.PORT);

  return {
    port: Number.isFinite(parsedPort) && parsedPort > 0 ? parsedPort : 3000,
    host: env.HOST?.trim() || '0.0.0.0',
    megaEmail,
    megaPassword,
    megaRootFolder: env.MEGA_ROOT_FOLDER?.trim() ?? '',
    syncroDbUrl: env.SYNCRO_DB_URL?.trim() || 'postgresql://postgres:@127.0.0.1:5432/syncro_erp',
    syncroPublicStorageDir: env.SYNCRO_PUBLIC_STORAGE_DIR?.trim() || 'C:/laragon/www/syncro_erp/storage/app/public',
    authTokenSecret: env.AUTH_TOKEN_SECRET?.trim() || 'replace-with-strong-secret',
    publicWebDir: env.PUBLIC_WEB_DIR?.trim() || path.resolve(import.meta.dirname, '..', 'public'),
  };
}
