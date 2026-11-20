import { describe, expect, it } from 'vitest';
import { buildApp } from '../src/app.js';
import {
  CloudVault,
  VaultFileNotFoundError,
  VaultPdfFile,
} from '../src/vault/cloud-vault.js';

function createInMemoryVault(): CloudVault {
  const samplePdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]);
  const files: VaultPdfFile[] = [
    {
      fileId: 'node-123',
      name: 'Surat_Perjanjian.pdf',
      size: samplePdfBytes.byteLength,
      updatedAt: '2026-11-20T02:30:00.000Z',
      isSigned: false,
    },
    {
      fileId: 'node-124',
      name: 'Invoice_Bulanan_signed.pdf',
      size: samplePdfBytes.byteLength,
      updatedAt: '2026-11-20T03:00:00.000Z',
      isSigned: true,
    },
  ];

  return {
    async listPdfFiles() {
      return files;
    },
    async downloadPdf(fileId: string) {
      const found = files.find((f) => f.fileId === fileId);
      if (!found) {
        throw new VaultFileNotFoundError(fileId);
      }
      return { file: found, bytes: samplePdfBytes };
    },
    async uploadSignedPdf() {
      throw new Error('Not used in read route tests');
    },
  };
}

describe('GET /api/files & GET /api/files/:fileId/download', () => {
  it('GET /api/files returns HTTP 200 and full PDF list', async () => {
    const app = buildApp({ vault: createInMemoryVault() });
    const res = await app.inject({ method: 'GET', url: '/api/files' });

    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({
      files: [
        {
          fileId: 'node-123',
          name: 'Surat_Perjanjian.pdf',
          size: 8,
          updatedAt: '2026-11-20T02:30:00.000Z',
          isSigned: false,
        },
        {
          fileId: 'node-124',
          name: 'Invoice_Bulanan_signed.pdf',
          size: 8,
          updatedAt: '2026-11-20T03:00:00.000Z',
          isSigned: true,
        },
      ],
    });

    await app.close();
  });

  it('GET /api/files?search=perjanjian filters files case-insensitively', async () => {
    const app = buildApp({ vault: createInMemoryVault() });
    const res = await app.inject({
      method: 'GET',
      url: '/api/files?search=perjanjian',
    });

    expect(res.statusCode).toBe(200);
    const body = res.json();
    expect(body.files).toHaveLength(1);
    expect(body.files[0].name).toBe('Surat_Perjanjian.pdf');

    await app.close();
  });

  it('GET /api/files/:fileId/download returns HTTP 200 with application/pdf header and matching binary content', async () => {
    const app = buildApp({ vault: createInMemoryVault() });
    const res = await app.inject({
      method: 'GET',
      url: '/api/files/node-123/download',
    });

    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('application/pdf');
    expect(res.headers['content-disposition']).toContain('Surat_Perjanjian.pdf');
    expect(Array.from(res.rawPayload)).toEqual([
      0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37,
    ]);

    await app.close();
  });

  it('GET /api/files/:fileId/download returns HTTP 404 JSON error when fileId is not found', async () => {
    const app = buildApp({ vault: createInMemoryVault() });
    const res = await app.inject({
      method: 'GET',
      url: '/api/files/unknown-id/download',
    });

    expect(res.statusCode).toBe(404);
    expect(res.json()).toEqual({
      error: 'File PDF tidak ditemukan di Mega.nz',
    });

    await app.close();
  });
});
