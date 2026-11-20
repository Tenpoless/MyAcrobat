# 13 — Halaman Login `syncro_erp`, Guard Role, & Sinkronisasi Auto-Save TTD di Aplikasi Flutter

Status: resolved
Type: task
Blocked by: 06, 08, 12

## Tujuan & Ruang Lingkup

Mengintegrasikan halaman Login `syncro_erp`, pengecekan Role pengguna (`admin` / `signer` / `viewer`), serta sinkronisasi dua arah **Saved Signature** antara cache lokal Flutter dan kolom `users.signature_path` di server `syncro_erp`.

> **Batasan Tiket:** Tiket ini menambahkan layar Login NIK/Email `syncro_erp` di Flutter, menyinkronkan `SavedSignatureRepository` (Tiket 08) dengan `users.signature_path` dari response login / `PUT /api/me/signature`, dan menyembunyikan tombol **"Bubuhkan Tanda Tangan"** apabila role user adalah `viewer`.

## Detail Pekerjaan

1. **State Autentikasi & Layar Login (`app/lib/src/features/auth/`):**
   - `AuthController` menyimpan sesi login (`token`, `user.name`, `user.position`, `user.role`) di `shared_preferences` dan menyuntikkan header `Authorization: Bearer <token>` pada `MyAcrobatApiClient`.
   - `LoginScreen`: form login ringkas menggunakan **NIK (`username`) atau Email `syncro_erp`** dan **Password** (+ tombol pengaturan IP Server Kantor).
2. **Sinkronisasi Otomatis Tanda Tangan (`users.signature_path` $\leftrightarrow$ Lokal Perangkat):**
   - Saat login berhasil: jika `user.signatureImageBase64` dari `syncro_erp` sudah ada, otomatis simpan ke `SavedSignatureRepository` lokal sehingga ketika user menekan **"Tanda Tangan"**, TTD dari `syncro_erp` langsung menempel ke PDF tanpa perlu menggambar ulang!
   - Saat user belum punya TTD di `syncro_erp` (atau menekan **"Ganti TTD"**) lalu menggambar di `SignaturePadSheet`: selain auto-save ke penyimpanan lokal HP/PC, aplikasi otomatis mengirim `PUT /api/me/signature` ke backend agar `users.signature_path` di `syncro_erp` ikut terisi/terbarui.
3. **Penyesuaian UI Berdasarkan Role:**
   - Menampilkan nama user, jabatan (`position`), dan badge role di header `DocumentListScreen` beserta tombol Logout.
   - Jika `user.role == 'viewer'`, pengguna dapat membaca dan mengunduh PDF dari Mega.nz tetapi tombol **"Bubuhkan Tanda Tangan"** & **"Simpan Dokumen"** dinonaktifkan/disembunyikan dengan keterangan `"Mode Baca (Viewer)"`.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test (Red → Green):**
  1. Login dengan NIK & password valid menyimpan sesi user dan apabila user sudah memiliki `signature_path` di `syncro_erp`, `SavedSignatureRepository.hasSavedSignature()` langsung bernilai `true` tanpa membuka `SignaturePadSheet`.
  2. Ketika user pertama kali menggambar TTD di `SignaturePadSheet`, aplikasi memanggil `PUT /api/me/signature` untuk menyinkronkan gambar TTD ke `users.signature_path` di `syncro_erp`.
  3. Ketika user dengan role `viewer` membuka dokumen PDF, tombol `"Bubuhkan Tanda Tangan"` tidak dapat digunakan, sedangkan untuk role `signer` dan `admin` tombol aktif sepenuhnya.

## Acceptance Criteria

- [x] Pengguna dapat login memakai akun `syncro_erp` (NIK / Email & Password).
- [x] TTD yang sudah ada di `syncro_erp` (`users.signature_path`) otomatis terbawa ke aplikasi Flutter tanpa perlu gambar ulang.
- [x] TTD baru yang digambar di aplikasi Flutter otomatis tersimpan ke lokal dan memperbarui `users.signature_path` di `syncro_erp`.
- [x] Hak akses tombol tanda tangan mematuhi role user (`admin`/`signer` vs `viewer`).
- [x] Seluruh test di `app/test/syncro_auth_and_signature_sync_test.dart` lulus.

## Comments

- **2026-11-20 (Resolved):**
  - Membuat model `SyncroUser` & `AuthLoginResult` (`app/lib/src/models/syncro_user.dart`) dan memperbarui `MyAcrobatApiClient` (`setAuthToken`, `login`, `fetchCurrentUser`, `uploadUserSignature`).
  - Membuat `AuthController` (`app/lib/src/features/auth/auth_controller.dart`) dan `LoginScreen` (`app/lib/src/features/auth/login_screen.dart`) untuk login menggunakan NIK/Email + Password `syncro_erp` beserta pengaturan cepat IP Server Kantor.
  - Menyambungkan sinkronisasi dua arah `SavedSignatureRepository` $\leftrightarrow$ `users.signature_path` (`syncro_erp`): saat login berhasil, `signatureImageBase64` dari server disimpan ke `SavedSignatureRepository`; saat user menggambar di `SignaturePadSheet`, gambar PNG disimpan ke lokal sekaligus diunggah ke `PUT /api/me/signature`.
  - Menambahkan informasi user, jabatan (`position`), badge role, dan tombol Logout di `DocumentListScreen`, serta guard `"Mode Baca (Viewer)"` di `PdfSigningScreen` untuk role `viewer`.
  - Seluruh test di `app/test/syncro_auth_and_signature_sync_test.dart` (`3 passed`, total Flutter test suite: `6 file test, 24 passed`) lulus.
