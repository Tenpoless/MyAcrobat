import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import pg from 'pg';
export function normalizeLaravelBcryptHash(hash) {
    if (hash.startsWith('$2y$')) {
        return `$2a$${hash.slice(4)}`;
    }
    return hash;
}
export async function verifyLaravelBcryptPassword(plainPassword, storedHash) {
    if (!plainPassword || !storedHash) {
        return false;
    }
    const normalized = normalizeLaravelBcryptHash(storedHash.trim());
    return bcrypt.compare(plainPassword, normalized);
}
function normalizeRole(rawRole) {
    const lower = rawRole?.trim().toLowerCase() ?? '';
    if (lower === 'admin' || lower === 'superadmin' || lower === 'super_admin') {
        return 'admin';
    }
    if (lower === 'viewer' || lower === 'read_only' || lower === 'readonly') {
        return 'viewer';
    }
    return 'signer';
}
export function createAuthToken(user, secret) {
    const payload = {
        sub: user.id,
        username: user.username,
        role: user.role,
        iat: Date.now(),
    };
    const encodedPayload = Buffer.from(JSON.stringify(payload), 'utf-8').toString('base64url');
    const signature = crypto
        .createHmac('sha256', secret)
        .update(encodedPayload)
        .digest('base64url');
    return `${encodedPayload}.${signature}`;
}
export function verifyAuthToken(token, secret) {
    const parts = token.trim().split('.');
    if (parts.length !== 2) {
        return null;
    }
    const [encodedPayload, providedSig] = parts;
    const expectedSig = crypto
        .createHmac('sha256', secret)
        .update(encodedPayload)
        .digest('base64url');
    const a = Buffer.from(providedSig);
    const b = Buffer.from(expectedSig);
    if (a.byteLength !== b.byteLength || !crypto.timingSafeEqual(a, b)) {
        return null;
    }
    try {
        const parsed = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf-8'));
        if (typeof parsed.sub !== 'number') {
            return null;
        }
        return parsed;
    }
    catch {
        return null;
    }
}
export class PostgresSyncroUserDirectory {
    db;
    publicStorageDir;
    constructor(options) {
        this.publicStorageDir = options.publicStorageDir;
        this.db =
            options.db ??
                new pg.Pool({
                    connectionString: options.connectionString,
                });
    }
    readSignatureDataUri(signaturePath) {
        if (!signaturePath || !signaturePath.trim()) {
            return null;
        }
        const cleanRel = signaturePath.trim().replace(/^\/+/, '');
        const resolvedRoot = path.resolve(this.publicStorageDir);
        const fullPath = path.resolve(resolvedRoot, cleanRel);
        if (!fullPath.startsWith(resolvedRoot) || !fs.existsSync(fullPath)) {
            return null;
        }
        const bytes = fs.readFileSync(fullPath);
        if (bytes.byteLength === 0) {
            return null;
        }
        return `data:image/png;base64,${bytes.toString('base64')}`;
    }
    toUserProfile(row) {
        const signatureImageBase64 = this.readSignatureDataUri(row.signature_path);
        return {
            id: Number(row.id),
            name: row.name,
            username: row.username,
            email: row.email,
            position: row.position ?? null,
            role: normalizeRole(row.role_name),
            hasSavedSignature: signatureImageBase64 !== null,
            signatureImageBase64,
        };
    }
    async authenticate(identifier, password) {
        const trimmedIdentifier = identifier.trim();
        if (!trimmedIdentifier || !password) {
            return null;
        }
        const sql = `
      SELECT
        u.id,
        u.name,
        u.username,
        u.email,
        u.password,
        u.position,
        u.signature_path,
        u.is_active,
        u.deleted_at,
        mra.role_name
      FROM users u
      LEFT JOIN module_role_assignments mra
        ON mra.user_id = u.id AND mra.module_key = 'myacrobat'
      WHERE COALESCE(u.is_active::text, '') IN ('1', 'true', 't')
        AND u.deleted_at IS NULL
        AND (LOWER(u.username) = LOWER($1) OR LOWER(u.email) = LOWER($1))
      LIMIT 1
    `;
        const result = await this.db.query(sql, [trimmedIdentifier]);
        const row = result.rows[0];
        if (!row || !row.password) {
            return null;
        }
        const isPasswordValid = await verifyLaravelBcryptPassword(password, row.password);
        if (!isPasswordValid) {
            return null;
        }
        return this.toUserProfile(row);
    }
    async getUserById(userId) {
        const sql = `
      SELECT
        u.id,
        u.name,
        u.username,
        u.email,
        u.position,
        u.signature_path,
        u.is_active,
        u.deleted_at,
        mra.role_name
      FROM users u
      LEFT JOIN module_role_assignments mra
        ON mra.user_id = u.id AND mra.module_key = 'myacrobat'
      WHERE u.id = $1
        AND COALESCE(u.is_active::text, '') IN ('1', 'true', 't')
        AND u.deleted_at IS NULL
      LIMIT 1
    `;
        const result = await this.db.query(sql, [userId]);
        const row = result.rows[0];
        if (!row) {
            return null;
        }
        return this.toUserProfile(row);
    }
    async saveUserSignature(userId, pngBytes) {
        const fileName = `myacrobat_user_${userId}_${Date.now()}.png`;
        const relativeSignaturePath = `signatures/${fileName}`;
        const signaturesDir = path.resolve(this.publicStorageDir, 'signatures');
        await fs.promises.mkdir(signaturesDir, { recursive: true });
        const fullFilePath = path.join(signaturesDir, fileName);
        await fs.promises.writeFile(fullFilePath, Buffer.from(pngBytes));
        await this.db.query(`UPDATE users SET signature_path = $1, updated_at = NOW() WHERE id = $2`, [relativeSignaturePath, userId]);
        const signatureImageBase64 = `data:image/png;base64,${Buffer.from(pngBytes).toString('base64')}`;
        return {
            signaturePath: relativeSignaturePath,
            hasSavedSignature: true,
            signatureImageBase64,
        };
    }
}
