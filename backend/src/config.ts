import fs from 'node:fs';
import path from 'node:path';

export interface AppConfig {
  port: number;
  host: string;
  megaRootFolder: string;
  megacmdBinDir: string;
  syncroDbUrl: string;
  syncroPublicStorageDir: string;
  authTokenSecret: string;
  publicWebDir: string;
}

function resolveDefaultMegaCmdBinDir(env: NodeJS.ProcessEnv): string {
  const localAppData = env.LOCALAPPDATA?.trim();
  if (localAppData) {
    const candidate = path.join(localAppData, 'MEGAcmd');
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }
  return '';
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsedPort = Number(env.PORT);

  return {
    port: Number.isFinite(parsedPort) && parsedPort > 0 ? parsedPort : 3000,
    host: env.HOST?.trim() || '0.0.0.0',
    megaRootFolder: env.MEGA_ROOT_FOLDER?.trim() ?? '',
    megacmdBinDir: env.MEGACMD_BIN_DIR?.trim() || resolveDefaultMegaCmdBinDir(env),
    syncroDbUrl: env.SYNCRO_DB_URL?.trim() || 'postgresql://postgres:@127.0.0.1:5432/syncro',
    syncroPublicStorageDir:
      env.SYNCRO_PUBLIC_STORAGE_DIR?.trim() || 'C:/laragon/www/syncro_erp/storage/app/public',
    authTokenSecret: env.AUTH_TOKEN_SECRET?.trim() || 'replace-with-strong-secret',
    publicWebDir: env.PUBLIC_WEB_DIR?.trim() || path.resolve(import.meta.dirname, '..', 'public'),
  };
}
