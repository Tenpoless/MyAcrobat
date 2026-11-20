import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { buildApp } from '../src/app.js';

describe('loadConfig', () => {
  it('parses PORT, MEGA_EMAIL, MEGA_PASSWORD, and MEGA_ROOT_FOLDER from env', () => {
    const config = loadConfig({
      PORT: '4050',
      HOST: '127.0.0.1',
      MEGA_EMAIL: 'vault@example.com',
      MEGA_PASSWORD: 'secret-password',
      MEGA_ROOT_FOLDER: 'MyAcrobat',
      SYNCRO_DB_URL: 'postgresql://postgres:@127.0.0.1:5432/syncro_erp',
      SYNCRO_PUBLIC_STORAGE_DIR: 'C:/laragon/www/syncro_erp/storage/app/public',
      AUTH_TOKEN_SECRET: 'custom-secret',
    });

    expect(config).toEqual(
      expect.objectContaining({
        port: 4050,
        host: '127.0.0.1',
        megaEmail: 'vault@example.com',
        megaPassword: 'secret-password',
        megaRootFolder: 'MyAcrobat',
        syncroDbUrl: 'postgresql://postgres:@127.0.0.1:5432/syncro_erp',
        syncroPublicStorageDir: 'C:/laragon/www/syncro_erp/storage/app/public',
        authTokenSecret: 'custom-secret',
      })
    );
  });

  it('throws clear error when MEGA_EMAIL or MEGA_PASSWORD is missing', () => {
    expect(() => loadConfig({ MEGA_EMAIL: 'vault@example.com' })).toThrow(
      'Missing required Mega.nz credentials in environment: MEGA_EMAIL, MEGA_PASSWORD'
    );
    expect(() => loadConfig({ MEGA_PASSWORD: 'secret' })).toThrow(
      'Missing required Mega.nz credentials in environment: MEGA_EMAIL, MEGA_PASSWORD'
    );
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
