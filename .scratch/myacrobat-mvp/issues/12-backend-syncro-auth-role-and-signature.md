# 12 — Modul Autentikasi, Role, & Sinkronisasi Tanda Tangan (`signature_path`) dengan PostgreSQL `syncro_erp` (Backend)

Status: resolved
Type: task
Blocked by: 01

## Tujuan & Ruang Lingkup

Menghubungkan backend Node.js MyAcrobat secara langsung ke database PostgreSQL `syncro_erp` (`users` dan `module_role_assignments`) serta folder `storage/app/public/signatures` milik `syncro_erp` sehingga:
1. Pengguna login menggunakan `username` (NIK) atau `email` + `password` `syncro_erp` (verifikasi hash bcrypt `$2y$` Laravel).
2. Role pengguna di MyAcrobat dibaca otomatis dari `module_role_assignments` (`module_key = 'myacrobat'`, atau fallback ke role aktif user) untuk menentukan kewenangan (mis. `admin`, `signer` / penandatangan, atau `viewer`).
3. Spesimen tanda tangan pengguna pada kolom `users.signature_path` di `syncro_erp` dapat langsung diambil (`GET /api/me/signature`) dan otomatis diperbarui (`PUT /api/me/signature`) ketika pengguna pertama kali menggambar atau mengganti tanda tangannya di MyAcrobat.

> **Batasan Tiket:** Tiket ini fokus pada adapter PostgreSQL `SyncroUserAdapter` + endpoint `POST /api/auth/login`, `GET /api/me`, dan `GET` / `PUT /api/me/signature` di sisi backend Node.js.

## Detail Pekerjaan

1. **Interface & Adapter `SyncroUserDirectory` (`backend/src/auth/syncro-user-directory.ts`):**
   - Membaca user aktif (`is_active = true` dan `deleted_at IS NULL`) dari tabel `users` PostgreSQL `syncro_erp` berdasarkan `username` atau `email`.
   - Memverifikasi password bcrypt Laravel (`$2y$...` dinormalisasi ke `$2a$/$2b$` untuk `bcryptjs`).
   - Membaca `role_name` dari tabel `module_role_assignments` untuk `module_key = 'myacrobat'` (default `'signer'` jika user aktif di `syncro_erp` belum diset spesifik, atau dapat dibatasi sesuai konfigurasi).
   - Membaca file gambar tanda tangan dari `<SYNCRO_PUBLIC_STORAGE_DIR>/<signature_path>` dan mengembalikannya sebagai `data:image/png;base64,...` (atau `null` jika user belum pernah memiliki TTD di `syncro_erp`).
   - Menyimpan gambar tanda tangan baru (`saveUserSignature(userId, pngBytes)`): menulis file `signatures/myacrobat_user_<id>_<timestamp>.png` ke `<SYNCRO_PUBLIC_STORAGE_DIR>/signatures/` dan menjalankan `UPDATE users SET signature_path = $1, updated_at = NOW() WHERE id = $2`.
2. **Endpoint Auth & Profil TTD (`backend/src/routes/auth-routes.ts`):**
   - `POST /api/auth/login` (`{ identifier, password }`) $\rightarrow$ mengembalikan `{ token, user: { id, name, username, email, position, role, hasSavedSignature, signatureImageBase64 } }`.
   - `GET /api/me` $\rightarrow$ mengembalikan profil user beserta `role` dan `signatureImageBase64` terbaru dari `syncro_erp`.
   - `PUT /api/me/signature` (`{ signatureImageBase64 }`) $\rightarrow$ menyimpan gambar PNG tanda tangan ke `users.signature_path` milik `syncro_erp` sehingga otomatis tersinkronisasi antara MyAcrobat dan web `syncro_erp`.
3. **Proteksi Role pada `POST /api/files/:fileId/sign`:**
   - Memastikan user dengan role `viewer` tidak dapat melakukan penandatanganan dokumen (HTTP `403 Forbidden`), sedangkan `signer` dan `admin` diizinkan.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/syncro-auth-and-signature.test.ts`
- **Skenario Test (Red → Green):**
  1. `POST /api/auth/login` dengan `username` (NIK) dan hash password bcrypt Laravel `$2y$12$...` yang cocok mengembalikan HTTP `200`, token valid, `role` dari `module_role_assignments`, dan `signatureImageBase64` jika `users.signature_path` sudah ada.
  2. `POST /api/auth/login` dengan password salah atau `is_active = false` mengembalikan HTTP `401`.
  3. `PUT /api/me/signature` menyimpan file PNG ke direktori storage `signatures/` dan memperbarui kolom `users.signature_path` user tersebut.
  4. User dengan role `viewer` yang memanggil `POST /api/files/:fileId/sign` ditolak dengan HTTP `403`.

## Acceptance Criteria

- [x] Login mendukung hash bcrypt `$2y$` milik tabel `users` `syncro_erp` menggunakan `username` (NIK) atau `email`.
- [x] Role pengguna terbaca dari `module_role_assignments` (`module_key = 'myacrobat'`).
- [x] Kolom `users.signature_path` di `syncro_erp` terhubung dua arah (baca TTD yang sudah ada & auto-save TTD baru).
- [x] Seluruh unit/integration test di `backend/tests/syncro-auth-and-signature.test.ts` lulus.

## Comments

- **2026-11-20 (Resolved):**
  - Membuat `backend/src/auth/syncro-user-directory.ts` (`SyncroUserDirectory`, `PostgresSyncroUserDirectory`, `verifyLaravelBcryptPassword` dengan normalisasi `$2y$` $\rightarrow$ `$2a$`, pembacaan `module_role_assignments` untuk `module_key = 'myacrobat'`, pembacaan dan penulisan file tanda tangan di `<SYNCRO_PUBLIC_STORAGE_DIR>/signatures/myacrobat_user_<id>_<timestamp>.png` beserta `UPDATE users SET signature_path = $1`).
  - Membuat `backend/src/routes/auth-routes.ts` (`POST /api/auth/login`, `GET /api/me`, `GET /api/me/signature`, `PUT /api/me/signature`) dan menambahkan guard role `viewer` (`403 Forbidden`) pada `POST /api/files/:fileId/sign` di `backend/src/app.ts`.
  - Seluruh test di `backend/tests/syncro-auth-and-signature.test.ts` (`4 passed`, total backend: `7 file test, 27 passed`) lulus.
