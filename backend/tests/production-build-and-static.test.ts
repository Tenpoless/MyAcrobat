import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { CloudVault, VaultPdfFile } from '../src/vault/cloud-vault.js';

const backendDir = path.resolve(import.meta.dirname, '..');
const repoRoot = path.resolve(backendDir, '..');

describe('Ticket 11: Production build, static web hosting, and deployment artifacts', () => {
  it('loads publicWebDir from PUBLIC_WEB_DIR in loadConfig with default fallback', () => {
    const configWithCustomDir = loadConfig({
      MEGA_EMAIL: 'office@example.com',
      MEGA_PASSWORD: 'secret',
      PUBLIC_WEB_DIR: './custom-public',
    });
    expect(configWithCustomDir.publicWebDir).toBe('./custom-public');

    const configDefault = loadConfig({
      MEGA_EMAIL: 'office@example.com',
      MEGA_PASSWORD: 'secret',
    });
    expect(configDefault.publicWebDir).toContain('public');
  });

  it('serves index.html and static assets from publicWebDir while keeping /health and /api/files working', async () => {
    const tmpWebDir = fs.mkdtempSync(path.join(os.tmpdir(), 'myacrobat-web-'));
    try {
      fs.writeFileSync(
        path.join(tmpWebDir, 'index.html'),
        '<!doctype html><html><head><title>MyAcrobat Web</title></head><body>MyAcrobat Office Portal</body></html>',
        'utf-8'
      );
      fs.writeFileSync(
        path.join(tmpWebDir, 'flutter_bootstrap.js'),
        'console.log("myacrobat-web-ready");',
        'utf-8'
      );

      const fakeFiles: VaultPdfFile[] = [
        {
          fileId: 'f-1',
          name: 'Kontrak.pdf',
          size: 1024,
          updatedAt: '2026-11-20T00:00:00.000Z',
          isSigned: false,
        },
      ];
      const fakeVault: CloudVault = {
        listPdfFiles: async () => fakeFiles,
        downloadPdf: async () => ({
          file: fakeFiles[0],
          bytes: new Uint8Array([0x25, 0x50, 0x44, 0x46]),
        }),
        uploadSignedPdf: async () => ({
          ...fakeFiles[0],
          fileId: 'f-2',
          name: 'Kontrak_signed.pdf',
          isSigned: true,
        }),
      };

      const app = buildApp({
        vault: fakeVault,
        publicWebDir: tmpWebDir,
      });

      const rootRes = await app.inject({ method: 'GET', url: '/' });
      expect(rootRes.statusCode).toBe(200);
      expect(rootRes.headers['content-type']).toContain('text/html');
      expect(rootRes.body).toContain('MyAcrobat Office Portal');

      const jsRes = await app.inject({ method: 'GET', url: '/flutter_bootstrap.js' });
      expect(jsRes.statusCode).toBe(200);
      expect(jsRes.headers['content-type']).toContain('javascript');
      expect(jsRes.body).toContain('myacrobat-web-ready');

      const healthRes = await app.inject({ method: 'GET', url: '/health' });
      expect(healthRes.statusCode).toBe(200);
      expect(healthRes.json()).toEqual({
        status: 'ok',
        service: 'myacrobat-backend',
      });

      const apiRes = await app.inject({ method: 'GET', url: '/api/files' });
      expect(apiRes.statusCode).toBe(200);
      expect(apiRes.json().files).toHaveLength(1);
    } finally {
      fs.rmSync(tmpWebDir, { recursive: true, force: true });
    }
  });

  it('compiles TypeScript cleanly and verifies all office deployment & build scripts exist', () => {
    execSync('npm run build', { cwd: backendDir, stdio: 'pipe' });
    expect(fs.existsSync(path.join(backendDir, 'dist', 'server.js'))).toBe(true);

    const requiredFiles = [
      path.join(backendDir, 'ecosystem.config.cjs'),
      path.join(backendDir, 'Dockerfile'),
      path.join(repoRoot, 'docker-compose.yml'),
      path.join(repoRoot, 'scripts', 'start-office-server.ps1'),
      path.join(repoRoot, 'scripts', 'start-office-server.bat'),
      path.join(repoRoot, 'scripts', 'build-release.ps1'),
      path.join(repoRoot, 'scripts', 'build-release.sh'),
      path.join(repoRoot, 'DEPLOY.md'),
    ];

    for (const filePath of requiredFiles) {
      expect(fs.existsSync(filePath), `Expected ${filePath} to exist`).toBe(true);
    }
  });
});
