import { execFile } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

export interface VaultPdfFile {
  fileId: string;
  name: string;
  size: number;
  updatedAt: string;
  isSigned: boolean;
}

export interface CloudVault {
  listPdfFiles(): Promise<VaultPdfFile[]>;
  downloadPdf(fileId: string): Promise<{ file: VaultPdfFile; bytes: Uint8Array }>;
  uploadSignedPdf(sourceFileId: string, signedPdfBytes: Uint8Array): Promise<VaultPdfFile>;
}

export class VaultFileNotFoundError extends Error {
  constructor(fileId: string) {
    super(`File PDF dengan ID "${fileId}" tidak ditemukan di Mega.nz`);
    this.name = 'VaultFileNotFoundError';
  }
}

const SIGNED_PDF_REGEX = /_signed(?:_\d+)?\.pdf$/i;

export function isSignedPdfName(name: string): boolean {
  return SIGNED_PDF_REGEX.test(name.trim());
}

export function resolveSignedFileName(
  originalName: string,
  existingNames: Iterable<string> = []
): string {
  const trimmed = originalName.trim();
  const withoutExt = trimmed.replace(/\.pdf$/i, '');
  const baseName = withoutExt.replace(/_signed(?:_\d+)?$/i, '');

  const existingLower = new Set(Array.from(existingNames, (n) => n.trim().toLowerCase()));
  const firstCandidate = `${baseName}_signed.pdf`;

  if (!existingLower.has(firstCandidate.toLowerCase())) {
    return firstCandidate;
  }

  let counter = 2;
  while (existingLower.has(`${baseName}_signed_${counter}.pdf`.toLowerCase())) {
    counter += 1;
  }
  return `${baseName}_signed_${counter}.pdf`;
}

export function encodeFileNameToId(fileName: string): string {
  return Buffer.from(fileName.trim(), 'utf8').toString('base64url');
}

export function decodeFileIdToName(fileId: string): string {
  try {
    return Buffer.from(fileId.trim(), 'base64url').toString('utf8');
  } catch {
    return '';
  }
}

export type MegaCmdCommandRunner = (
  subcommand: 'ls' | 'get' | 'put' | 'whoami',
  args: string[]
) => Promise<{ stdout: string; stderr: string }>;

export interface MegaCmdCloudVaultOptions {
  rootFolder?: string;
  binDir?: string;
  commandRunner?: MegaCmdCommandRunner;
}

function normalizeRemoteFolder(rootFolder?: string): string {
  const cleaned = (rootFolder ?? '').trim().replace(/^\/+|\/+$/g, '');
  return cleaned ? `/${cleaned}` : '/';
}

function buildRemoteFilePath(remoteFolder: string, fileName: string): string {
  return remoteFolder === '/' ? `/${fileName}` : `${remoteFolder}/${fileName}`;
}

function createDefaultMegaCmdRunner(binDir?: string): MegaCmdCommandRunner {
  const resolvedBinDir = (binDir ?? '').trim();

  return async (subcommand, args) => {
    const isWin = process.platform === 'win32';
    let executable: string;
    let execArgs: string[];

    if (isWin) {
      const candidateExe = resolvedBinDir
        ? path.join(resolvedBinDir, 'MEGAclient.exe')
        : path.join(process.env.LOCALAPPDATA ?? '', 'MEGAcmd', 'MEGAclient.exe');
      executable = fs.existsSync(candidateExe) ? candidateExe : 'MEGAclient.exe';
      execArgs = [subcommand, ...args];
    } else {
      executable = resolvedBinDir
        ? path.join(resolvedBinDir, `mega-${subcommand}`)
        : `mega-${subcommand}`;
      execArgs = args;
    }

    const result = await execFileAsync(executable, execArgs, {
      windowsHide: true,
      maxBuffer: 10 * 1024 * 1024,
    });
    return {
      stdout: String(result.stdout ?? ''),
      stderr: String(result.stderr ?? ''),
    };
  };
}

// Matches file lines in `mega-ls -l --time-format=ISO6081_WITH_TIME`
// Example: "----    1     1024 2026-11-20T06:00:00 Welcome to MEGA.pdf"
const LS_ISO_FILE_LINE_REGEX =
  /^-[-\w]{3}\s+(?:\d+|-)\s+(\d+)\s+(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\s+(.+)$/;

function parseIsoUtcTimestamp(rawIso: string): string {
  const withZ = rawIso.endsWith('Z') ? rawIso : `${rawIso}Z`;
  const parsed = new Date(withZ);
  return Number.isNaN(parsed.getTime()) ? new Date(0).toISOString() : parsed.toISOString();
}

function normalizeMegaCmdError(err: unknown): Error {
  const message = err instanceof Error ? err.message : String(err);
  if (/not logged in/i.test(message)) {
    return new Error(
      'MEGAcmd belum login. Jalankan perintah "login <email>" di MEGAcmdShell terlebih dahulu.'
    );
  }
  return err instanceof Error ? err : new Error(message);
}

export class MegaCmdCloudVaultAdapter implements CloudVault {
  private readonly remoteFolder: string;
  private readonly commandRunner: MegaCmdCommandRunner;

  constructor(options: MegaCmdCloudVaultOptions = {}) {
    this.remoteFolder = normalizeRemoteFolder(options.rootFolder);
    this.commandRunner = options.commandRunner ?? createDefaultMegaCmdRunner(options.binDir);
  }

  private async runCommand(
    subcommand: 'ls' | 'get' | 'put' | 'whoami',
    args: string[]
  ): Promise<{ stdout: string; stderr: string }> {
    try {
      const output = await this.commandRunner(subcommand, args);
      if (/not logged in/i.test(output.stderr) || /not logged in/i.test(output.stdout)) {
        throw new Error(output.stderr || output.stdout);
      }
      return output;
    } catch (err) {
      throw normalizeMegaCmdError(err);
    }
  }

  async listPdfFiles(): Promise<VaultPdfFile[]> {
    const { stdout } = await this.runCommand('ls', [
      '-l',
      '--time-format=ISO6081_WITH_TIME',
      this.remoteFolder,
    ]);

    const files: VaultPdfFile[] = [];
    for (const rawLine of stdout.split(/\r?\n/)) {
      const line = rawLine.trim();
      const match = LS_ISO_FILE_LINE_REGEX.exec(line);
      if (!match) {
        continue;
      }

      const size = Number(match[1]) || 0;
      const rawDate = match[2];
      const name = match[3].trim();

      if (!name.toLowerCase().endsWith('.pdf')) {
        continue;
      }

      files.push({
        fileId: encodeFileNameToId(name),
        name,
        size,
        updatedAt: parseIsoUtcTimestamp(rawDate),
        isSigned: isSignedPdfName(name),
      });
    }

    return files.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  async downloadPdf(fileId: string): Promise<{ file: VaultPdfFile; bytes: Uint8Array }> {
    const files = await this.listPdfFiles();
    const targetFile = files.find((f) => f.fileId === fileId);
    if (!targetFile) {
      throw new VaultFileNotFoundError(fileId);
    }

    const tempDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'myacrobat-get-'));
    try {
      const remoteFilePath = buildRemoteFilePath(this.remoteFolder, targetFile.name);
      await this.runCommand('get', [remoteFilePath, tempDir]);

      const localFilePath = path.join(tempDir, targetFile.name);
      if (!fs.existsSync(localFilePath)) {
        throw new VaultFileNotFoundError(fileId);
      }

      const buffer = await fs.promises.readFile(localFilePath);
      return {
        file: targetFile,
        bytes: new Uint8Array(buffer),
      };
    } finally {
      await fs.promises.rm(tempDir, { recursive: true, force: true });
    }
  }

  async uploadSignedPdf(
    sourceFileId: string,
    signedPdfBytes: Uint8Array
  ): Promise<VaultPdfFile> {
    const files = await this.listPdfFiles();
    const sourceFile = files.find((f) => f.fileId === sourceFileId);
    if (!sourceFile) {
      throw new VaultFileNotFoundError(sourceFileId);
    }

    const existingNames = files.map((f) => f.name);
    const signedName = resolveSignedFileName(sourceFile.name, existingNames);

    const tempDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'myacrobat-put-'));
    try {
      const localFilePath = path.join(tempDir, signedName);
      await fs.promises.writeFile(localFilePath, Buffer.from(signedPdfBytes));

      const remoteTargetDir =
        this.remoteFolder === '/' ? '/' : `${this.remoteFolder}/`;
      await this.runCommand('put', [localFilePath, remoteTargetDir]);

      return {
        fileId: encodeFileNameToId(signedName),
        name: signedName,
        size: signedPdfBytes.byteLength,
        updatedAt: new Date().toISOString(),
        isSigned: isSignedPdfName(signedName),
      };
    } finally {
      await fs.promises.rm(tempDir, { recursive: true, force: true });
    }
  }
}
