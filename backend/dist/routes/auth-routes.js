import { createAuthToken, verifyAuthToken, } from '../auth/syncro-user-directory.js';
function extractPngBytes(input) {
    if (typeof input !== 'string' || !input.trim()) {
        return null;
    }
    const base64Payload = input.trim().replace(/^data:image\/png;base64,/i, '');
    if (!base64Payload) {
        return null;
    }
    const bytes = Buffer.from(base64Payload, 'base64');
    const isPng = bytes.byteLength >= 8 &&
        bytes[0] === 0x89 &&
        bytes[1] === 0x50 &&
        bytes[2] === 0x4e &&
        bytes[3] === 0x47;
    return isPng ? bytes : null;
}
export async function authenticateBearerRequest(req, userDirectory, authTokenSecret) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
        return null;
    }
    const token = authHeader.slice(7).trim();
    const payload = verifyAuthToken(token, authTokenSecret);
    if (!payload) {
        return null;
    }
    return userDirectory.getUserById(payload.sub);
}
export function registerAuthRoutes(app, options) {
    const { userDirectory, authTokenSecret } = options;
    const requireAuthenticatedUser = async (req, reply) => {
        const user = await authenticateBearerRequest(req, userDirectory, authTokenSecret);
        if (!user) {
            reply.code(401).send({ error: 'Sesi tidak valid atau sudah berakhir' });
            return null;
        }
        return user;
    };
    app.post('/api/auth/login', async (req, reply) => {
        const body = req.body ?? {};
        const identifier = (body.identifier ?? body.username ?? body.email ?? '').trim();
        const password = body.password ?? '';
        if (!identifier || !password) {
            return reply
                .code(400)
                .send({ error: 'NIK/Email (identifier) dan password wajib diisi' });
        }
        const user = await userDirectory.authenticate(identifier, password);
        if (!user) {
            return reply
                .code(401)
                .send({ error: 'NIK/Email atau password Syncro ERP tidak valid' });
        }
        const token = createAuthToken(user, authTokenSecret);
        return reply.code(200).send({
            token,
            user,
        });
    });
    app.get('/api/me', async (req, reply) => {
        const user = await requireAuthenticatedUser(req, reply);
        if (!user) {
            return;
        }
        return { user };
    });
    app.get('/api/me/signature', async (req, reply) => {
        const user = await requireAuthenticatedUser(req, reply);
        if (!user) {
            return;
        }
        return {
            hasSavedSignature: user.hasSavedSignature,
            signatureImageBase64: user.signatureImageBase64,
        };
    });
    app.put('/api/me/signature', async (req, reply) => {
        const user = await requireAuthenticatedUser(req, reply);
        if (!user) {
            return;
        }
        const pngBytes = extractPngBytes(req.body?.signatureImageBase64);
        if (!pngBytes) {
            return reply
                .code(400)
                .send({ error: 'signatureImageBase64 wajib berisi gambar PNG yang valid' });
        }
        const saved = await userDirectory.saveUserSignature(user.id, pngBytes);
        return reply.code(200).send(saved);
    });
}
