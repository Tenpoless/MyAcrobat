import fs from 'node:fs';
import path from 'node:path';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import { VaultFileNotFoundError } from './vault/cloud-vault.js';
import { InvalidSignaturePlacementError, embedSignatureIntoPdf, } from './pdf/pdf-signature-embedder.js';
import { authenticateBearerRequest, registerAuthRoutes, } from './routes/auth-routes.js';
const STATIC_MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.mjs': 'application/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.ttf': 'font/ttf',
    '.otf': 'font/otf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
};
function isValidPngBase64(input) {
    if (typeof input !== 'string' || !input.trim()) {
        return false;
    }
    const base64Payload = input.trim().replace(/^data:image\/png;base64,/i, '');
    if (!base64Payload) {
        return false;
    }
    const bytes = Buffer.from(base64Payload, 'base64');
    return (bytes.byteLength >= 8 &&
        bytes[0] === 0x89 &&
        bytes[1] === 0x50 &&
        bytes[2] === 0x4e &&
        bytes[3] === 0x47);
}
export function buildApp(options = {}) {
    const { vault, publicWebDir, userDirectory, authTokenSecret = 'replace-with-strong-secret', ...fastifyOptions } = options;
    const app = Fastify({
        bodyLimit: 20 * 1024 * 1024,
        ...fastifyOptions,
    });
    app.register(cors);
    app.get('/health', async () => ({
        status: 'ok',
        service: 'myacrobat-backend',
    }));
    if (userDirectory) {
        registerAuthRoutes(app, { userDirectory, authTokenSecret });
    }
    if (vault) {
        app.get('/api/files', async (req) => {
            const allFiles = await vault.listPdfFiles();
            const keyword = req.query.search?.trim().toLowerCase();
            const files = keyword
                ? allFiles.filter((file) => file.name.toLowerCase().includes(keyword))
                : allFiles;
            return { files };
        });
        app.get('/api/files/:fileId/download', async (req, reply) => {
            try {
                const { file, bytes } = await vault.downloadPdf(req.params.fileId);
                return reply
                    .header('Content-Type', 'application/pdf')
                    .header('Content-Disposition', `inline; filename="${file.name}"`)
                    .header('Content-Length', bytes.byteLength)
                    .send(Buffer.from(bytes));
            }
            catch (err) {
                if (err instanceof VaultFileNotFoundError) {
                    return reply.code(404).send({ error: 'File PDF tidak ditemukan di Mega.nz' });
                }
                throw err;
            }
        });
        app.post('/api/files/:fileId/sign', async (req, reply) => {
            if (userDirectory && req.headers.authorization) {
                const authUser = await authenticateBearerRequest(req, userDirectory, authTokenSecret);
                if (!authUser) {
                    return reply
                        .code(401)
                        .send({ error: 'Sesi login tidak valid atau telah berakhir' });
                }
                if (authUser.role === 'viewer') {
                    return reply
                        .code(403)
                        .send({ error: 'Role viewer tidak memiliki izin menandatangani dokumen' });
                }
            }
            const body = req.body ?? {};
            if (!isValidPngBase64(body.signatureImageBase64)) {
                return reply
                    .code(400)
                    .send({ error: 'signatureImageBase64 wajib diisi dengan PNG valid' });
            }
            if (!Array.isArray(body.placements) || body.placements.length === 0) {
                return reply
                    .code(400)
                    .send({ error: 'Minimal satu posisi tanda tangan (placements) wajib dikirim' });
            }
            try {
                const { bytes: sourcePdfBytes } = await vault.downloadPdf(req.params.fileId);
                const signedPdfBytes = await embedSignatureIntoPdf({
                    pdfBytes: sourcePdfBytes,
                    signaturePngBase64OrBytes: body.signatureImageBase64,
                    placements: body.placements,
                });
                const signedFile = await vault.uploadSignedPdf(req.params.fileId, signedPdfBytes);
                return reply.code(201).send({
                    message: 'Dokumen berhasil ditandatangani dan disimpan ke Mega.nz',
                    sourceFileId: req.params.fileId,
                    signedFile,
                });
            }
            catch (err) {
                if (err instanceof VaultFileNotFoundError) {
                    return reply.code(404).send({ error: 'File PDF tidak ditemukan di Mega.nz' });
                }
                if (err instanceof InvalidSignaturePlacementError) {
                    return reply.code(400).send({ error: err.message });
                }
                throw err;
            }
        });
    }
    if (publicWebDir) {
        const resolvedRoot = path.resolve(publicWebDir);
        const serveWebAsset = async (rawReqPath, reply) => {
            if (!fs.existsSync(resolvedRoot)) {
                return reply.code(404).send({ error: 'Not Found' });
            }
            const cleanPath = rawReqPath.split('?')[0].replace(/^\/+/, '') || 'index.html';
            const candidatePath = path.resolve(resolvedRoot, cleanPath);
            if (!candidatePath.startsWith(resolvedRoot)) {
                return reply.code(403).send({ error: 'Forbidden' });
            }
            let targetFile = candidatePath;
            if (!fs.existsSync(targetFile) || fs.statSync(targetFile).isDirectory()) {
                const indexFallback = path.join(resolvedRoot, 'index.html');
                if (!path.extname(cleanPath) && fs.existsSync(indexFallback)) {
                    targetFile = indexFallback;
                }
                else {
                    return reply.code(404).send({ error: 'Not Found' });
                }
            }
            const ext = path.extname(targetFile).toLowerCase();
            const contentType = STATIC_MIME_TYPES[ext] ?? 'application/octet-stream';
            const content = await fs.promises.readFile(targetFile);
            return reply.header('Content-Type', contentType).send(content);
        };
        app.get('/', async (_req, reply) => serveWebAsset('index.html', reply));
        app.get('/*', async (req, reply) => {
            if (req.url.startsWith('/api/') || req.url === '/health') {
                return reply.code(404).send({ error: 'Not Found' });
            }
            return serveWebAsset(req.url, reply);
        });
    }
    return app;
}
