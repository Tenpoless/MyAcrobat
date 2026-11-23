# 19 — Ubah Placeholder Input Email/Username menjadi `example@gmail.com`

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Menyederhanakan placeholder (`hintText`) pada kotak input Email/Username di halaman login (`app/lib/src/features/auth/login_screen.dart`) agar cukup menampilkan `example@gmail.com`.

## Detail Pekerjaan

1. **Placeholder Input Identifier (`app/lib/src/features/auth/login_screen.dart` baris 132):**
   - Ubah `hintText: 'example@gmail.com atau username'` pada `TextField(key: Key('login_identifier_input'))` menjadi `hintText: 'example@gmail.com'`.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart` (baris 389)
- **Skenario Test:**
  - Pastikan `TextField` dengan `Key('login_identifier_input')` memiliki `decoration.hintText == 'example@gmail.com'`.
- **Verifikasi:**
  - `flutter test --no-pub test/syncro_auth_and_signature_sync_test.dart` lulus.

## Acceptance Criteria

- [x] Placeholder kotak input Email/Username pada `LoginScreen` hanya menampilkan `'example@gmail.com'`.
- [x] Widget test terkait diperbarui dan lulus.

## Comments

- **2026-11-23**: Tiket 19 selesai dieksekusi (`login_screen.dart` dan `syncro_auth_and_signature_sync_test.dart`). `flutter test --no-pub test/syncro_auth_and_signature_sync_test.dart` lulus (+4 tests).
