import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { buildApp } from '../src/app.js';

describe('loadConfig', () => {
  it('parses PORT, MEGA_ROOT_FOLDER, and MEGACMD_BIN_DIR from env without requiring MEGA_EMAIL or MEGA_PASSWORD', () => {
    const config = loadConfig({
      PORT: '4050',
      HOST: '127.0.0.1',
      MEGA_ROOT_FOLDER: 'Testing',
      MEGACMD_BIN_DIR: 'C:/Users/FARIZQI/AppData/Local/MEGAcmd',
      SYNCRO_DB_URL: 'postgresql://postgres:@127.0.0.1:5432/syncro',
      SYNCRO_PUBLIC_STORAGE_DIR: 'C:/laragon/www/syncro_erp/storage/app/public',
      AUTH_TOKEN_SECRET: 'custom-secret',
    });

    expect(config).toEqual(
      expect.objectContaining({
        port: 4050,
        host: '127.0.0.1',
        megaRootFolder: 'Testing',
        megacmdBinDir: 'C:/Users/FARIZQI/AppData/Local/MEGAcmd',
        syncroDbUrl: 'postgresql://postgres:@127.0.0.1:5432/syncro',
        syncroPublicStorageDir: 'C:/laragon/www/syncro_erp/storage/app/public',
        authTokenSecret: 'custom-secret',
      })
    );
  });

  it('provides sensible defaults when optional env vars are omitted', () => {
    const config = loadConfig({});
    expect(config.port).toBe(3000);
    expect(config.host).toBe('0.0.0.0');
    expect(config.megaRootFolder).toBe('');
  });
});

describe('GET /health', () => {
  it('returns HTTP 200 with ok status and service name', async () => {
    const app = buildApp();
    const res = await app.inject({ method: 'GET', url: '/health' });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      status: 'ok',
      service: 'myacrobat-backend',
    });

    await app.close();
  });
});
