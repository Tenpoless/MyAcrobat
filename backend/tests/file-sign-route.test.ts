import { describe, expect, it } from 'vitest';
import { PDFDocument } from 'pdf-lib';
import { buildApp } from '../src/app.js';
import {
  CloudVault,
  VaultFileNotFoundError,
  VaultPdfFile,
  resolveSignedFileName,
} from '../src/vault/cloud-vault.js';

const TRANSPARENT_1X1_PNG_BASE64 =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

async function createInMemorySigningVault() {
  const doc = await PDFDocument.create();
  doc.addPage([600, 800]);
  const originalPdfBytes = await doc.save();

  const store = new Map<string, { meta: VaultPdfFile; bytes: Uint8Array }>();
  store.set('node-123', {
    meta: {
      fileId: 'node-123',
      name: 'Surat_Perjanjian.pdf',
      size: originalPdfBytes.byteLength,
      updatedAt: '2026-11-20T02:30:00.000Z',
      isSigned: false,
    },
    bytes: new Uint8Array(originalPdfBytes),
  });

  const vault: CloudVault = {
    async listPdfFiles() {
      return Array.from(store.values(), (entry) => entry.meta);
    },
    async downloadPdf(fileId: string) {
      const entry = store.get(fileId);
      if (!entry) {
        throw new VaultFileNotFoundError(fileId);
      }
      return { file: entry.meta, bytes: new Uint8Array(entry.bytes) };
    },
    async uploadSignedPdf(sourceFileId: string, signedPdfBytes: Uint8Array) {
      const source = store.get(sourceFileId);
      if (!source) {
        throw new VaultFileNotFoundError(sourceFileId);
      }
      const existingNames = Array.from(store.values(), (e) => e.meta.name);
      const signedName = resolveSignedFileName(source.meta.name, existingNames);
      const signedMeta: VaultPdfFile = {
        fileId: `node-${store.size + 123}`,
        name: signedName,
        size: signedPdfBytes.byteLength,
        updatedAt: '2026-11-20T03:10:00.000Z',
        isSigned: true,
      };
      store.set(signedMeta.fileId, {
        meta: signedMeta,
        bytes: new Uint8Array(signedPdfBytes),
      });
      return signedMeta;
    },
  };

  return { vault, store, originalPdfBytes };
}

describe('POST /api/files/:fileId/sign', () => {
  it('embeds PNG signature, uploads new _signed.pdf to CloudVault (HTTP 201), and preserves original file', async () => {
    const { vault, store, originalPdfBytes } = await createInMemorySigningVault();
    const app = buildApp({ vault });

    const res = await app.inject({
      method: 'POST',
      url: '/api/files/node-123/sign',
      payload: {
        signatureImageBase64: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          {
            pageIndex: 0,
            xRatio: 0.62,
            yRatio: 0.78,
            widthRatio: 0.22,
            heightRatio: 0.08,
          },
        ],
      },
    });

    expect(res.statusCode).toBe(201);
    const body = res.json();
    expect(body.message).toBe('Dokumen berhasil ditandatangani dan disimpan ke Mega.nz');
    expect(body.sourceFileId).toBe('node-123');
    expect(body.signedFile.name).toBe('Surat_Perjanjian_signed.pdf');
    expect(body.signedFile.isSigned).toBe(true);
    expect(body.signedFile.size).toBeGreaterThan(originalPdfBytes.byteLength);

    // Non-destructive verification: original file still exists and its bytes are untouched
    const originalAfter = store.get('node-123');
    expect(originalAfter).toBeDefined();
    expect(Array.from(originalAfter!.bytes)).toEqual(Array.from(originalPdfBytes));

    await app.close();
  });

  it('returns HTTP 400 when signatureImageBase64 is missing/invalid or placements is empty', async () => {
    const { vault } = await createInMemorySigningVault();
    const app = buildApp({ vault });

    const resMissingSig = await app.inject({
      method: 'POST',
      url: '/api/files/node-123/sign',
      payload: {
        signatureImageBase64: '',
        placements: [
          { pageIndex: 0, xRatio: 0.5, yRatio: 0.5, widthRatio: 0.2, heightRatio: 0.1 },
        ],
      },
    });
    expect(resMissingSig.statusCode).toBe(400);
    expect(resMissingSig.json().error).toContain('signatureImageBase64');

    const resEmptyPlacements = await app.inject({
      method: 'POST',
      url: '/api/files/node-123/sign',
      payload: {
        signatureImageBase64: TRANSPARENT_1X1_PNG_BASE64,
        placements: [],
      },
    });
    expect(resEmptyPlacements.statusCode).toBe(400);
    expect(resEmptyPlacements.json().error).toContain('placements');

    await app.close();
  });

  it('returns HTTP 400 when pageIndex is out of range for the PDF', async () => {
    const { vault } = await createInMemorySigningVault();
    const app = buildApp({ vault });

    const res = await app.inject({
      method: 'POST',
      url: '/api/files/node-123/sign',
      payload: {
        signatureImageBase64: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          { pageIndex: 99, xRatio: 0.5, yRatio: 0.5, widthRatio: 0.2, heightRatio: 0.1 },
        ],
      },
    });

    expect(res.statusCode).toBe(400);
    expect(res.json().error).toContain('pageIndex');

    await app.close();
  });

  it('returns HTTP 404 when :fileId does not exist in CloudVault', async () => {
    const { vault } = await createInMemorySigningVault();
    const app = buildApp({ vault });

    const res = await app.inject({
      method: 'POST',
      url: '/api/files/non-existent/sign',
      payload: {
        signatureImageBase64: TRANSPARENT_1X1_PNG_BASE64,
        placements: [
          { pageIndex: 0, xRatio: 0.5, yRatio: 0.5, widthRatio: 0.2, heightRatio: 0.1 },
        ],
      },
    });

    expect(res.statusCode).toBe(404);
    expect(res.json().error).toContain('tidak ditemukan');

    await app.close();
  });
});
