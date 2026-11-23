import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import {
  MegaCmdCloudVaultAdapter,
  MegaCmdCommandRunner,
  VaultFileNotFoundError,
  encodeFileNameToId,
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

function createFakeMegaCmdRunner(): {
  runner: MegaCmdCommandRunner;
  calls: Array<{ subcommand: string; args: string[] }>;
  uploadedFiles: Array<{ name: string; bytes: Uint8Array; remoteTarget: string }>;
} {
  const samplePdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46]); // %PDF
  const calls: Array<{ subcommand: string; args: string[] }> = [];
  const uploadedFiles: Array<{ name: string; bytes: Uint8Array; remoteTarget: string }> = [];

  const lsOutput = [
    '/Testing:',
    'FLAGS VERS    SIZE            DATE       NAME',
    '----    1     1024 2026-11-20T06:00:00 Welcome to MEGA.pdf',
    '----    1     2048 2026-11-20T07:30:00 Welcome to MEGA_signed.pdf',
    '----    1      512 2026-11-20T08:00:00 Logo.png',
    'd---    -        - 2026-11-20T05:00:00 Subfolder.pdf',
  ].join('\n');

  const runner: MegaCmdCommandRunner = async (subcommand, args) => {
    calls.push({ subcommand, args });

    if (subcommand === 'ls') {
      return { stdout: lsOutput, stderr: '' };
    }

    if (subcommand === 'get') {
      const [remoteFilePath, localDestDir] = args;
      const baseName = path.posix.basename(remoteFilePath);
      await fs.promises.writeFile(
        path.join(localDestDir, baseName),
        Buffer.from(samplePdfBytes)
      );
      return { stdout: 'Download finished', stderr: '' };
    }

    if (subcommand === 'put') {
      const [localSourceFile, remoteTarget] = args;
      const bytes = await fs.promises.readFile(localSourceFile);
      uploadedFiles.push({
        name: path.basename(localSourceFile),
        bytes: new Uint8Array(bytes),
        remoteTarget,
      });
      return { stdout: 'Upload finished', stderr: '' };
    }

    throw new Error(`Unexpected subcommand: ${subcommand}`);
  };

  return { runner, calls, uploadedFiles };
}

describe('MegaCmdCloudVaultAdapter (MEGAcmd CLI integration)', () => {
  it('lists only .pdf files (preserving spaces in filenames, ignoring non-PDFs and folders), marks isSigned accurately, sorted newest first', async () => {
    const { runner, calls } = createFakeMegaCmdRunner();
    const adapter = new MegaCmdCloudVaultAdapter({
      rootFolder: 'Testing',
      commandRunner: runner,
    });

    const files = await adapter.listPdfFiles();

    expect(calls[0]).toEqual({
      subcommand: 'ls',
      args: ['-l', '--time-format=ISO6081_WITH_TIME', '/Testing'],
    });
    expect(files).toEqual([
      {
        fileId: encodeFileNameToId('Welcome to MEGA_signed.pdf'),
        name: 'Welcome to MEGA_signed.pdf',
        size: 2048,
        updatedAt: '2026-11-20T07:30:00.000Z',
        isSigned: true,
      },
      {
        fileId: encodeFileNameToId('Welcome to MEGA.pdf'),
        name: 'Welcome to MEGA.pdf',
        size: 1024,
        updatedAt: '2026-11-20T06:00:00.000Z',
        isSigned: false,
      },
    ]);
  });

  it('downloads PDF bytes via MEGAcmd get and throws VaultFileNotFoundError when missing', async () => {
    const { runner } = createFakeMegaCmdRunner();
    const adapter = new MegaCmdCloudVaultAdapter({
      rootFolder: 'Testing',
      commandRunner: runner,
    });

    const targetId = encodeFileNameToId('Welcome to MEGA.pdf');
    const result = await adapter.downloadPdf(targetId);

    expect(result.file.name).toBe('Welcome to MEGA.pdf');
    expect(Array.from(result.bytes)).toEqual([0x25, 0x50, 0x44, 0x46]);

    await expect(adapter.downloadPdf(encodeFileNameToId('TidakAda.pdf'))).rejects.toThrow(
      VaultFileNotFoundError
    );
  });

  it('uploads a signed PDF via MEGAcmd put using non-destructive _signed naming without overwriting existing files', async () => {
    const { runner, uploadedFiles } = createFakeMegaCmdRunner();
    const adapter = new MegaCmdCloudVaultAdapter({
      rootFolder: 'Testing',
      commandRunner: runner,
    });

    const sourceId = encodeFileNameToId('Welcome to MEGA.pdf');
    const signedBytes = new Uint8Array([1, 2, 3, 4, 5]);
    const uploaded = await adapter.uploadSignedPdf(sourceId, signedBytes);

    expect(uploaded.name).toBe('Welcome to MEGA_signed_2.pdf');
    expect(uploaded.fileId).toBe(encodeFileNameToId('Welcome to MEGA_signed_2.pdf'));
    expect(uploaded.isSigned).toBe(true);
    expect(uploaded.size).toBe(5);
    expect(uploadedFiles).toHaveLength(1);
    expect(uploadedFiles[0].name).toBe('Welcome to MEGA_signed_2.pdf');
    expect(uploadedFiles[0].remoteTarget).toBe('/Testing/');
    expect(Array.from(uploadedFiles[0].bytes)).toEqual([1, 2, 3, 4, 5]);
  });

  it('throws actionable error when MEGAcmd daemon is not logged in', async () => {
    const adapter = new MegaCmdCloudVaultAdapter({
      rootFolder: 'Testing',
      commandRunner: async () => {
        throw new Error('[2026-11-20_07-46-03 cmd ERR  Not logged in.]');
      },
    });

    await expect(adapter.listPdfFiles()).rejects.toThrow(/MEGAcmd belum login/i);
  });
});
