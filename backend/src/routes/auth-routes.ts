import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import {
  SyncroUserDirectory,
  SyncroUserProfile,
  createAuthToken,
  verifyAuthToken,
} from '../auth/syncro-user-directory.js';

export interface AuthRoutesOptions {
  userDirectory: SyncroUserDirectory;
  authTokenSecret: string;
}

interface LoginBody {
  identifier?: string;
  username?: string;
  email?: string;
  password?: string;
}

interface PutSignatureBody {
  signatureImageBase64?: string;
}

function extractPngBytes(input: unknown): Buffer | null {
  if (typeof input !== 'string' || !input.trim()) {
    return null;
  }
  const base64Payload = input.trim().replace(/^data:image\/png;base64,/i, '');
  if (!base64Payload) {
    return null;
  }
  const bytes = Buffer.from(base64Payload, 'base64');
  const isPng =
    bytes.byteLength >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47;
  return isPng ? bytes : null;
}

export async function authenticateBearerRequest(
  req: FastifyRequest,
  userDirectory: SyncroUserDirectory,
  authTokenSecret: string
): Promise<SyncroUserProfile | null> {
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

export function registerAuthRoutes(
  app: FastifyInstance,
  options: AuthRoutesOptions
): void {
  const { userDirectory, authTokenSecret } = options;

  const requireAuthenticatedUser = async (
    req: FastifyRequest,
    reply: FastifyReply
  ): Promise<SyncroUserProfile | null> => {
    const user = await authenticateBearerRequest(req, userDirectory, authTokenSecret);
    if (!user) {
      reply.code(401).send({ error: 'Sesi tidak valid atau sudah berakhir' });
      return null;
    }
    return user;
  };

  app.post<{ Body: LoginBody }>('/api/auth/login', async (req, reply) => {
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

  app.put<{ Body: PutSignatureBody }>('/api/me/signature', async (req, reply) => {
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
