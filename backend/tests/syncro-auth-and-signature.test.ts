import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { PDFDocument } from 'pdf-lib';
import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import {
  PgQueryExecutor,
  PostgresSyncroUserDirectory,
  verifyLaravelBcryptPassword,
} from '../src/auth/syncro-user-directory.js';
import { CloudVault, VaultPdfFile } from '../src/vault/cloud-vault.js';

const SAMPLE_PNG_BASE64 =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';
const SAMPLE_PNG_BYTES = Buffer.from(
  SAMPLE_PNG_BASE64.replace(/^data:image\/png;base64,/, ''),
  'base64'
);

// Laravel bcrypt hash ($2y$10$) for plaintext password: "secret-password"
const LARAVEL_HASH_FOR_SECRET_PASSWORD =
  '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi'; // standard Laravel hash for "password"

interface FakeDbUserRow {
  id: number;
  name: string;
  username: string;
  email: string;
  password: string;
  position: string | null;
  signature_path: string | null;
  is_active: boolean;
  deleted_at: string | null;
  role_name: string | null;
}

function createFakePgExecutor(rows: FakeDbUserRow[]): {
  executor: PgQueryExecutor;
  rows: FakeDbUserRow[];
} {
  return {
    rows,
    executor: {
      async query<T = Record<string, unknown>>(sql: string, params: unknown[] = []) {
        const normalizedSql = sql.toLowerCase();
        if (normalizedSql.includes('update users')) {
          const newSigPath = String(params[0]);
          const userId = Number(params[1]);
          const target = rows.find((r) => r.id === userId);
          if (target) {
            target.signature_path = newSigPath;
          }
          return { rows: [] as T[] };
        }

        if (normalizedSql.includes('where u.id =')) {
          const userId = Number(params[0]);
          const match = rows.filter(
            (r) => r.id === userId && r.is_active && r.deleted_at === null
          );
          return { rows: match as unknown as T[] };
        }

        const identifier = String(params[0] ?? '').toLowerCase();
        const match = rows.filter(
          (r) =>
            r.is_active &&
            r.deleted_at === null &&
            (r.username.toLowerCase() === identifier || r.email.toLowerCase() === identifier)
        );
        return { rows: match as unknown as T[] };
      },
    },
  };
}

describe('Ticket 12: Syncro ERP PostgreSQL Authentication, Role Assignment, and Signature Sync', () => {
  it('1. POST /api/auth/login with NIK (username) and Laravel $2y$ bcrypt hash returns 200, token, role from module_role_assignments, and existing signatureImageBase64', async () => {
    const tmpStorageDir = fs.mkdtempSync(path.join(os.tmpdir(), 'syncro-storage-'));
    try {
      const sigRelPath = 'signatures/existing_emp.png';
      const sigFullPath = path.join(tmpStorageDir, sigRelPath);
      fs.mkdirSync(path.dirname(sigFullPath), { recursive: true });
      fs.writeFileSync(sigFullPath, SAMPLE_PNG_BYTES);

      const { executor } = createFakePgExecutor([
        {
          id: 101,
          name: 'Budi Santoso',
          username: 'EMP-101',
          email: 'budi@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Manager Operasional',
          signature_path: sigRelPath,
          is_active: true,
          deleted_at: null,
          role_name: 'signer',
        },
      ]);

      expect(await verifyLaravelBcryptPassword('password', LARAVEL_HASH_FOR_SECRET_PASSWORD)).toBe(
        true
      );

      const userDirectory = new PostgresSyncroUserDirectory({
        db: executor,
        publicStorageDir: tmpStorageDir,
      });

      const app = buildApp({
        userDirectory,
        authTokenSecret: 'test-jwt-secret',
      });

      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: {
          identifier: 'EMP-101',
          password: 'password',
        },
      });

      expect(loginRes.statusCode).toBe(200);
      const body = loginRes.json();
      expect(typeof body.token).toBe('string');
      expect(body.token.length).toBeGreaterThan(16);
      expect(body.user).toEqual({
        id: 101,
        name: 'Budi Santoso',
        username: 'EMP-101',
        email: 'budi@syncro.co.id',
        position: 'Manager Operasional',
        role: 'signer',
        hasSavedSignature: true,
        signatureImageBase64: SAMPLE_PNG_BASE64,
      });

      const meRes = await app.inject({
        method: 'GET',
        url: '/api/me',
        headers: {
          authorization: `Bearer ${body.token}`,
        },
      });
      expect(meRes.statusCode).toBe(200);
      expect(meRes.json().user.username).toBe('EMP-101');
      expect(meRes.json().user.signatureImageBase64).toBe(SAMPLE_PNG_BASE64);

      const getSigRes = await app.inject({
        method: 'GET',
        url: '/api/me/signature',
        headers: {
          authorization: `Bearer ${body.token}`,
        },
      });
      expect(getSigRes.statusCode).toBe(200);
      expect(getSigRes.json()).toEqual({
        hasSavedSignature: true,
        signatureImageBase64: SAMPLE_PNG_BASE64,
      });
    } finally {
      fs.rmSync(tmpStorageDir, { recursive: true, force: true });
    }
  });

  it('2. POST /api/auth/login with wrong password or inactive user returns HTTP 401', async () => {
    const tmpStorageDir = fs.mkdtempSync(path.join(os.tmpdir(), 'syncro-storage-'));
    try {
      const { executor } = createFakePgExecutor([
        {
          id: 101,
          name: 'Budi Santoso',
          username: 'EMP-101',
          email: 'budi@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Manager',
          signature_path: null,
          is_active: true,
          deleted_at: null,
          role_name: 'signer',
        },
        {
          id: 102,
          name: 'Nonaktif User',
          username: 'EMP-102',
          email: 'nonaktif@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Staff',
          signature_path: null,
          is_active: false,
          deleted_at: null,
          role_name: 'signer',
        },
      ]);

      const userDirectory = new PostgresSyncroUserDirectory({
        db: executor,
        publicStorageDir: tmpStorageDir,
      });
      const app = buildApp({
        userDirectory,
        authTokenSecret: 'test-jwt-secret',
      });

      const wrongPassRes = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: {
          identifier: 'EMP-101',
          password: 'wrong-password',
        },
      });
      expect(wrongPassRes.statusCode).toBe(401);

      const inactiveRes = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: {
          identifier: 'EMP-102',
          password: 'password',
        },
      });
      expect(inactiveRes.statusCode).toBe(401);
    } finally {
      fs.rmSync(tmpStorageDir, { recursive: true, force: true });
    }
  });

  it('3. PUT /api/me/signature saves PNG file into storage signatures/ folder and updates users.signature_path', async () => {
    const tmpStorageDir = fs.mkdtempSync(path.join(os.tmpdir(), 'syncro-storage-'));
    try {
      const { executor, rows } = createFakePgExecutor([
        {
          id: 205,
          name: 'Siti Rahma',
          username: 'EMP-205',
          email: 'siti@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Supervisor Finance',
          signature_path: null,
          is_active: true,
          deleted_at: null,
          role_name: 'admin',
        },
      ]);

      const userDirectory = new PostgresSyncroUserDirectory({
        db: executor,
        publicStorageDir: tmpStorageDir,
      });
      const app = buildApp({
        userDirectory,
        authTokenSecret: 'test-jwt-secret',
      });

      const loginRes = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: {
          identifier: 'siti@syncro.co.id',
          password: 'password',
        },
      });
      expect(loginRes.statusCode).toBe(200);
      const { token, user } = loginRes.json();
      expect(user.hasSavedSignature).toBe(false);
      expect(user.signatureImageBase64).toBeNull();

      const putSigRes = await app.inject({
        method: 'PUT',
        url: '/api/me/signature',
        headers: {
          authorization: `Bearer ${token}`,
        },
        payload: {
          signatureImageBase64: SAMPLE_PNG_BASE64,
        },
      });

      expect(putSigRes.statusCode).toBe(200);
      const putBody = putSigRes.json();
      expect(putBody.hasSavedSignature).toBe(true);
      expect(putBody.signatureImageBase64).toBe(SAMPLE_PNG_BASE64);
      expect(putBody.signaturePath).toMatch(/^signatures\/myacrobat_user_205_\d+\.png$/);

      expect(rows[0].signature_path).toBe(putBody.signaturePath);
      const savedDiskPath = path.join(tmpStorageDir, rows[0].signature_path!);
      expect(fs.existsSync(savedDiskPath)).toBe(true);
      expect(Buffer.compare(fs.readFileSync(savedDiskPath), SAMPLE_PNG_BYTES)).toBe(0);
    } finally {
      fs.rmSync(tmpStorageDir, { recursive: true, force: true });
    }
  });

  it('4. User with viewer role calling POST /api/files/:fileId/sign is rejected with HTTP 403 while signer/admin succeeds', async () => {
    const tmpStorageDir = fs.mkdtempSync(path.join(os.tmpdir(), 'syncro-storage-'));
    try {
      const { executor } = createFakePgExecutor([
        {
          id: 301,
          name: 'Viewer Staff',
          username: 'EMP-301',
          email: 'viewer@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Auditor',
          signature_path: null,
          is_active: true,
          deleted_at: null,
          role_name: 'viewer',
        },
        {
          id: 302,
          name: 'Signer Staff',
          username: 'EMP-302',
          email: 'signer@syncro.co.id',
          password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
          position: 'Legal Officer',
          signature_path: null,
          is_active: true,
          deleted_at: null,
          role_name: 'signer',
        },
      ]);

      const pdfDoc = await PDFDocument.create();
      pdfDoc.addPage([600, 800]);
      const validPdfBytes = await pdfDoc.save();

      const fakeFile: VaultPdfFile = {
        fileId: 'file-100',
        name: 'Kontrak.pdf',
        size: validPdfBytes.byteLength,
        updatedAt: '2026-11-20T00:00:00.000Z',
        isSigned: false,
      };

      const fakeVault: CloudVault = {
        listPdfFiles: async () => [fakeFile],
        downloadPdf: async () => ({ file: fakeFile, bytes: validPdfBytes }),
        uploadSignedPdf: async (_id, signedBytes) => ({
          fileId: 'file-101',
          name: 'Kontrak_signed.pdf',
          size: signedBytes.byteLength,
          updatedAt: '2026-11-20T01:00:00.000Z',
          isSigned: true,
        }),
      };

      const userDirectory = new PostgresSyncroUserDirectory({
        db: executor,
        publicStorageDir: tmpStorageDir,
      });

      const app = buildApp({
        vault: fakeVault,
        userDirectory,
        authTokenSecret: 'test-jwt-secret',
      });

      const viewerLogin = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: { identifier: 'EMP-301', password: 'password' },
      });
      const viewerToken = viewerLogin.json().token;

      const viewerSignRes = await app.inject({
        method: 'POST',
        url: '/api/files/file-100/sign',
        headers: {
          authorization: `Bearer ${viewerToken}`,
        },
        payload: {
          signatureImageBase64: SAMPLE_PNG_BASE64,
          placements: [
            {
              pageIndex: 0,
              xRatio: 0.5,
              yRatio: 0.7,
              widthRatio: 0.2,
              heightRatio: 0.08,
            },
          ],
        },
      });
      expect(viewerSignRes.statusCode).toBe(403);
      expect(viewerSignRes.json().error).toMatch(/viewer/i);

      const signerLogin = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: { identifier: 'EMP-302', password: 'password' },
      });
      const signerToken = signerLogin.json().token;

      const signerSignRes = await app.inject({
        method: 'POST',
        url: '/api/files/file-100/sign',
        headers: {
          authorization: `Bearer ${signerToken}`,
        },
        payload: {
          signatureImageBase64: SAMPLE_PNG_BASE64,
          placements: [
            {
              pageIndex: 0,
              xRatio: 0.5,
              yRatio: 0.7,
              widthRatio: 0.2,
              heightRatio: 0.08,
            },
          ],
        },
      });
      expect(signerSignRes.statusCode).toBe(201);
    } finally {
      fs.rmSync(tmpStorageDir, { recursive: true, force: true });
    }
  });

  it('5. SQL query supports smallint is_active (1/0) without comparing smallint = boolean', async () => {
    const capturedSqls: string[] = [];
    const spyExecutor: PgQueryExecutor = {
      async query<T = Record<string, unknown>>(sql: string) {
        capturedSqls.push(sql);
        return {
          rows: [
            {
              id: 89,
              name: 'Naufal',
              username: 'naufal',
              email: 'naufal@saraswanti.co.id',
              password: LARAVEL_HASH_FOR_SECRET_PASSWORD,
              position: null,
              signature_path: null,
              is_active: 1,
              deleted_at: null,
              role_name: null,
            },
          ] as unknown as T[],
        };
      },
    };

    const dir = new PostgresSyncroUserDirectory({
      db: spyExecutor,
      publicStorageDir: os.tmpdir(),
    });

    const authUser = await dir.authenticate('naufal', 'password');
    const fetchedUser = await dir.getUserById(89);

    expect(authUser?.username).toBe('naufal');
    expect(fetchedUser?.id).toBe(89);
    expect(capturedSqls).toHaveLength(2);
    for (const sql of capturedSqls) {
      expect(sql.toLowerCase()).not.toContain('is_active = true');
      expect(sql).toContain('is_active::text');
    }
  });
});
