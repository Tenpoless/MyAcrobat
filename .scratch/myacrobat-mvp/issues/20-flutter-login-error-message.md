# 20 — Ubah Pesan Gagal Login menjadi `Email atau Password salah`

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Mengganti pesan error saat proses login gagal pada `AuthController` (`app/lib/src/features/auth/auth_controller.dart`) agar menampilkan pesan singkat dan jelas: **`Email atau Password salah`**.

## Detail Pekerjaan

1. **Error Message pada `AuthController.login` (`app/lib/src/features/auth/auth_controller.dart` baris 121):**
   - Ubah:
     `errorMessage: 'Login gagal: Periksa NIK/Email, Password, atau koneksi Server Kantor.',`
   - Menjadi:
     `errorMessage: 'Email atau Password salah',`

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test:**
  - Simulasikan `apiClient.login(...)` melempar exception saat submit login di `LoginScreen` (atau panggil `AuthController.login` saat gagal).
  - Pastikan `authState.errorMessage == 'Email atau Password salah'` dan teks `'Email atau Password salah'` tampil di `LoginScreen`.
- **Verifikasi:**
  - `flutter test --no-pub test/syncro_auth_and_signature_sync_test.dart` lulus.

## Acceptance Criteria

- [x] Ketika login gagal, `LoginScreen` menampilkan pemberitahuan `'Email atau Password salah'`.
- [x] Pesan lama `'Login gagal: Periksa NIK/Email, Password, atau koneksi Server Kantor.'` tidak lagi digunakan.
- [x] Unit/widget test untuk skenario gagal login tersedia dan lulus.

## Comments

- **2026-11-23**: Tiket 20 selesai dieksekusi (`auth_controller.dart` dan test #5 di `syncro_auth_and_signature_sync_test.dart`). `flutter test --no-pub test/syncro_auth_and_signature_sync_test.dart` lulus (+5 tests).
