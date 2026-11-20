# 01 — Inisialisasi Proyek Backend (Node.js + TypeScript + Fastify) & Validasi Konfigurasi `.env`

Status: resolved
Type: task
Blocked by: none

## Tujuan & Ruang Lingkup

Menyiapkan kerangka dasar (*scaffold*) proyek backend di direktori `backend/` menggunakan **Node.js + TypeScript + Fastify + Vitest**, lengkap dengan pemuat konfigurasi `.env` untuk satu akun **Cloud Vault** Mega.nz terpusat serta satu endpoint `GET /health` sebagai *tracer bullet* pertama.

> **Batasan Tiket:** Tiket ini **tidak** mengimplementasikan koneksi ke SDK `megajs` maupun manipulasi `pdf-lib`. Fokus murni pada fondasi server, validasi environment variable, dan runner test Vitest yang siap jalan.

## Detail Pekerjaan

1. **Struktur Direktori `backend/`:**
   - `backend/package.json` (dependencies: `fastify`, `@fastify/cors`, `dotenv`, `pdf-lib`, `megajs`; devDependencies: `typescript`, `vitest`, `@types/node`, `tsx`).
   - `backend/tsconfig.json` (target `ES2022`, moduleResolution `node`, `strict: true`).
   - `backend/.env.example`:
     ```env
     PORT=3000
     HOST=0.0.0.0
     MEGA_EMAIL=your-mega-account@example.com
     MEGA_PASSWORD=your-mega-password
     MEGA_ROOT_FOLDER=MyAcrobat
     SYNCRO_DB_URL=postgresql://postgres:@127.0.0.1:5432/syncro_erp
     SYNCRO_PUBLIC_STORAGE_DIR=C:/laragon/www/syncro_erp/storage/app/public
     AUTH_TOKEN_SECRET=replace-with-strong-secret
     ```
2. **Modul Konfigurasi (`backend/src/config.ts`):**
   - Membuat fungsi `loadConfig(env: NodeJS.ProcessEnv = process.env)` yang memvalidasi dan mengembalikan objek konfigurasi bertipe:
     - `port: number` (default `3000`)
     - `host: string` (default `'0.0.0.0'`)
     - `megaEmail: string` (wajib terisi saat mode non-test)
     - `megaPassword: string` (wajib terisi saat mode non-test)
     - `megaRootFolder: string` (default `''` / root jika tidak diisi)
     - `syncroDbUrl: string` (connection string PostgreSQL `syncro_erp`)
     - `syncroPublicStorageDir: string` (path ke `storage/app/public` milik `syncro_erp` untuk membaca/menulis file `users.signature_path`)
     - `authTokenSecret: string` (secret HMAC untuk token sesi login MyAcrobat)
   - Jika `MEGA_EMAIL` atau `MEGA_PASSWORD` kosong, lempar `Error('Missing required Mega.nz credentials in environment: MEGA_EMAIL, MEGA_PASSWORD')`.
3. **Factory Server Fastify (`backend/src/app.ts` & `backend/src/server.ts`):**
   - `buildApp(options)` menginisialisasi instance Fastify, mendaftarkan `@fastify/cors`, menaikkan `bodyLimit` ke `20 * 1024 * 1024` (20 MB agar aman menerima Base64 tanda tangan), dan menyediakan route `GET /health` yang mengembalikan `{ status: 'ok', service: 'myacrobat-backend' }`.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/config-and-health.test.ts`
- **Skenario Test (Red → Green):**
  1. `loadConfig()` berhasil mem-parsing `PORT`, `MEGA_EMAIL`, `MEGA_PASSWORD`, dan `MEGA_ROOT_FOLDER` dari objek env.
  2. `loadConfig()` melempar error yang jelas apabila `MEGA_EMAIL` atau `MEGA_PASSWORD` tidak disetel.
  3. `GET /health` melalui `app.inject({ method: 'GET', url: '/health' })` mengembalikan HTTP `200` dengan `{ status: 'ok', service: 'myacrobat-backend' }`.

## Acceptance Criteria

- [x] Direktori `backend/` memiliki `package.json`, `tsconfig.json`, dan `.env.example`.
- [x] `loadConfig()` memvalidasi kredensial `MEGA_EMAIL` dan `MEGA_PASSWORD`.
- [x] `buildApp()` menyediakan `GET /health` dengan CORS aktif dan `bodyLimit` 20 MB.
- [x] Perintah `npm test` di dalam `backend/` lulus 100%.

## Comments

- Selesai diimplementasikan dan diverifikasi dengan Vitest (`3 passed`).
