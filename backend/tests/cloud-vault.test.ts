import { describe, expect, it } from 'vitest';
import {
  MegaCloudVaultAdapter,
  MegaFileNodeLike,
  VaultFileNotFoundError,
  resolveSignedFileName,
} from '../src/vault/cloud-vault.js';

describe('resolveSignedFileName (Signed Document non-destructive naming)', () => {
  it('appends _signed before .pdf when signing a Source Document for the first time', () => {
    expect(resolveSignedFileName('Kontrak.pdf', ['Kontrak.pdf'])).toBe('Kontrak_signed.pdf');
    expect(resolveSignedFileName('Surat_Perjanjian.PDF', ['Surat_Perjanjian.PDF'])).toBe(
      'Surat_Perjanjian_signed.pdf'
    );
  });

  it('increments numeric suffix (_signed_2.pdf, _signed_3.pdf) when _signed.pdf already exists', () => {
    expect(resolveSignedFileName('Kontrak.pdf', ['Kontrak.pdf', 'Kontrak_signed.pdf'])).toBe(
      'Kontrak_signed_2.pdf'
    );
    expect(
      resolveSignedFileName('Kontrak.pdf', [
        'Kontrak.pdf',
        'Kontrak_signed.pdf',
        'Kontrak_signed_2.pdf',
      ])
    ).toBe('Kontrak_signed_3.pdf');
  });

  it('does not stack _signed_signed.pdf when re-signing an already signed document', () => {
    expect(
      resolveSignedFileName('Kontrak_signed.pdf', ['Kontrak.pdf', 'Kontrak_signed.pdf'])
    ).toBe('Kontrak_signed_2.pdf');
    expect(
      resolveSignedFileName('Kontrak_signed_2.pdf', [
        'Kontrak.pdf',
        'Kontrak_signed.pdf',
        'Kontrak_signed_2.pdf',
      ])
    ).toBe('Kontrak_signed_3.pdf');
  });
});

function createFakeMegaStorage() {
  const samplePdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46]); // %PDF
  const workFolderChildren: MegaFileNodeLike[] = [
    {
      nodeId: 'node-1',
      name: 'Kontrak.pdf',
      size: 1024,
      timestamp: 1700000100,
      directory: false,
      downloadBuffer: async () => Buffer.from(samplePdfBytes),
    },
    {
      nodeId: 'node-2',
      name: 'Kontrak_signed.pdf',
      size: 2048,
      timestamp: 1700000500,
      directory: false,
      downloadBuffer: async () => Buffer.from(samplePdfBytes),
    },
    {
      nodeId: 'node-img',
      name: 'Logo.png',
      size: 512,
      timestamp: 1700000900,
      directory: false,
    },
    {
      nodeId: 'node-dir',
      name: 'Subfolder.pdf',
      directory: true,
      children: [],
    },
  ];

  const workFolder: MegaFileNodeLike = {
    nodeId: 'folder-myacrobat',
    name: 'MyAcrobat',
    directory: true,
    children: workFolderChildren,
    upload: ({ name, size }) => {
      const created: MegaFileNodeLike = {
        nodeId: `node-${workFolderChildren.length + 1}`,
        name,
        size: size ?? 0,
        timestamp: 1700001000,
        directory: false,
      };
      workFolderChildren.push(created);
      return { complete: Promise.resolve(created) };
    },
  };

  return {
    ready: Promise.resolve(),
    root: {
      nodeId: 'root',
      name: 'Cloud Drive',
      directory: true,
      children: [workFolder],
    },
  };
}

describe('MegaCloudVaultAdapter', () => {
  it('lists only .pdf files (ignoring non-PDFs and folders), marks isSigned accurately, sorted newest first', async () => {
    const adapter = new MegaCloudVaultAdapter({
      email: 'vault@example.com',
      password: 'secret',
      rootFolder: 'MyAcrobat',
      storageFactory: createFakeMegaStorage,
    });

    const files = await adapter.listPdfFiles();

    expect(files).toEqual([
      {
        fileId: 'node-2',
        name: 'Kontrak_signed.pdf',
        size: 2048,
        updatedAt: new Date(1700000500 * 1000).toISOString(),
        isSigned: true,
      },
      {
        fileId: 'node-1',
        name: 'Kontrak.pdf',
        size: 1024,
        updatedAt: new Date(1700000100 * 1000).toISOString(),
        isSigned: false,
      },
    ]);
  });

  it('downloads PDF bytes for an existing fileId and throws VaultFileNotFoundError when missing', async () => {
    const adapter = new MegaCloudVaultAdapter({
      email: 'vault@example.com',
      password: 'secret',
      rootFolder: 'MyAcrobat',
      storageFactory: createFakeMegaStorage,
    });

    const result = await adapter.downloadPdf('node-1');
    expect(result.file.name).toBe('Kontrak.pdf');
    expect(Array.from(result.bytes)).toEqual([0x25, 0x50, 0x44, 0x46]);

    await expect(adapter.downloadPdf('unknown-node')).rejects.toThrow(VaultFileNotFoundError);
  });

  it('uploads a signed PDF using non-destructive _signed naming without overwriting existing files', async () => {
    const adapter = new MegaCloudVaultAdapter({
      email: 'vault@example.com',
      password: 'secret',
      rootFolder: 'MyAcrobat',
      storageFactory: createFakeMegaStorage,
    });

    const signedBytes = new Uint8Array([1, 2, 3, 4, 5]);
    const uploaded = await adapter.uploadSignedPdf('node-1', signedBytes);

    expect(uploaded.name).toBe('Kontrak_signed_2.pdf');
    expect(uploaded.isSigned).toBe(true);
    expect(uploaded.size).toBe(5);
  });
});
