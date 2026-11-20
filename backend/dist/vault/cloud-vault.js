import { Storage } from 'megajs';
export class VaultFileNotFoundError extends Error {
    constructor(fileId) {
        super(`File PDF dengan ID "${fileId}" tidak ditemukan di Mega.nz`);
        this.name = 'VaultFileNotFoundError';
    }
}
const SIGNED_PDF_REGEX = /_signed(?:_\d+)?\.pdf$/i;
export function isSignedPdfName(name) {
    return SIGNED_PDF_REGEX.test(name.trim());
}
export function resolveSignedFileName(originalName, existingNames = []) {
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
function toIsoTimestamp(timestamp) {
    if (!timestamp || !Number.isFinite(timestamp)) {
        return new Date(0).toISOString();
    }
    const ms = timestamp < 1e12 ? timestamp * 1000 : timestamp;
    return new Date(ms).toISOString();
}
function mapNodeToVaultPdfFile(node) {
    const fileId = node.nodeId || node.downloadId || '';
    const name = node.name || 'unnamed.pdf';
    return {
        fileId,
        name,
        size: node.size ?? 0,
        updatedAt: toIsoTimestamp(node.timestamp),
        isSigned: isSignedPdfName(name),
    };
}
export class MegaCloudVaultAdapter {
    storagePromise = null;
    email;
    password;
    rootFolder;
    storageFactory;
    constructor(options) {
        this.email = options.email;
        this.password = options.password;
        this.rootFolder = (options.rootFolder ?? '').trim();
        this.storageFactory =
            options.storageFactory ??
                (() => new Storage({
                    email: this.email,
                    password: this.password,
                    keepalive: false,
                }));
    }
    async getTargetFolder() {
        if (!this.storagePromise) {
            this.storagePromise = (async () => {
                const storage = this.storageFactory();
                await storage.ready;
                return storage;
            })().catch((err) => {
                this.storagePromise = null;
                throw err;
            });
        }
        const storage = await this.storagePromise;
        if (!this.rootFolder) {
            return storage.root;
        }
        const segments = this.rootFolder.split('/').filter(Boolean);
        let current = storage.root;
        for (const segment of segments) {
            const children = current.children ?? [];
            const next = children.find((child) => child.directory && child.name?.toLowerCase() === segment.toLowerCase());
            if (!next) {
                throw new Error(`Folder Mega.nz "${this.rootFolder}" tidak ditemukan`);
            }
            current = next;
        }
        return current;
    }
    async listPdfFiles() {
        const folder = await this.getTargetFolder();
        const children = folder.children ?? [];
        return children
            .filter((node) => !node.directory &&
            typeof node.name === 'string' &&
            node.name.toLowerCase().endsWith('.pdf'))
            .map(mapNodeToVaultPdfFile)
            .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
    }
    async downloadPdf(fileId) {
        const folder = await this.getTargetFolder();
        const children = folder.children ?? [];
        const target = children.find((node) => !node.directory &&
            typeof node.name === 'string' &&
            node.name.toLowerCase().endsWith('.pdf') &&
            (node.nodeId === fileId || node.downloadId === fileId));
        if (!target || typeof target.downloadBuffer !== 'function') {
            throw new VaultFileNotFoundError(fileId);
        }
        const buffer = await target.downloadBuffer({});
        return {
            file: mapNodeToVaultPdfFile(target),
            bytes: new Uint8Array(buffer),
        };
    }
    async uploadSignedPdf(sourceFileId, signedPdfBytes) {
        const folder = await this.getTargetFolder();
        const children = folder.children ?? [];
        const sourceNode = children.find((node) => !node.directory &&
            typeof node.name === 'string' &&
            node.name.toLowerCase().endsWith('.pdf') &&
            (node.nodeId === sourceFileId || node.downloadId === sourceFileId));
        if (!sourceNode || !sourceNode.name) {
            throw new VaultFileNotFoundError(sourceFileId);
        }
        const existingNames = children
            .filter((node) => !node.directory && typeof node.name === 'string')
            .map((node) => node.name);
        const signedName = resolveSignedFileName(sourceNode.name, existingNames);
        if (typeof folder.upload !== 'function') {
            throw new Error('Folder Mega.nz tidak mendukung operasi upload');
        }
        const buffer = Buffer.from(signedPdfBytes);
        const uploadResult = folder.upload({ name: signedName, size: buffer.byteLength }, buffer);
        const uploadedNode = 'complete' in uploadResult
            ? await uploadResult.complete
            : await uploadResult;
        return mapNodeToVaultPdfFile(uploadedNode);
    }
}
