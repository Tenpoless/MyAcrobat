# 16 — Revisi Label dan Placeholder (Hint Text) Form Input Email/Username & Password pada `LoginScreen`

Status: resolved
Type: task
Blocked by: 15

## Tujuan & Ruang Lingkup

Memperbarui label field dan placeholder (`hintText`) pada form input Email/Username serta Password di `app/lib/src/features/auth/login_screen.dart` sesuai permintaan pengguna (poin revisi 4, 5, dan 6).

## Detail Pekerjaan

1. **Poin 4 — Label Field Identifier (`login_screen.dart`):**
   - Ubah label di atas input identifier (`Key('login_identifier_input')`) dari `'NIK (Username) atau Email'` menjadi **`'Email atau Username'`**.
2. **Poin 5 — Placeholder (`hintText`) Input Identifier (`login_screen.dart`):**
   - Ubah `hintText` pada `TextField` identifier (`Key('login_identifier_input')`) dari `'Contoh: EMP-101 atau nama@perusahaan.com'` menjadi **`'example@gmail.com atau username'`**.
3. **Poin 6 — Placeholder (`hintText`) Input Password (`login_screen.dart`):**
   - Ubah `hintText` pada `TextField` password (`Key('login_password_input')`) dari `'Masukkan password Syncro ERP'` menjadi **`'***'`**.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test (Red → Green):**
  1. Memastikan label `'Email atau Username'` tampil dan label lama `'NIK (Username) atau Email'` tidak ditemukan.
  2. Memastikan `TextField` dengan `Key('login_identifier_input')` memiliki `decoration.hintText == 'example@gmail.com atau username'`.
  3. Memastikan `TextField` dengan `Key('login_password_input')` memiliki `decoration.hintText == '***'`.

## Acceptance Criteria

- [x] Label input pertama menampilkan `'Email atau Username'`.
- [x] Placeholder input pertama menampilkan `'example@gmail.com atau username'`.
- [x] Placeholder input password menampilkan `'***'`.
- [x] Seluruh widget test pada `app/test/` lulus (`flutter test`).
