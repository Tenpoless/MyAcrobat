# 18 — Rebrand UI & Android App Label dari `MyAcrobat` menjadi `AgriSign`

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Mengubah seluruh branding yang terlihat pengguna pada aplikasi Flutter / APK dari `MyAcrobat` (`myacrobat_app`) menjadi **`AgriSign`** (termasuk label aplikasi Android di launcher, judul `MaterialApp`, header/tombol di `LoginScreen`, dan judul di `DocumentListScreen`).

> Catatan (Ponytail): Nama package Dart (`myacrobat_app`) dan nama class internal (`MyAcrobatApp`, `MyAcrobatApiClient`) tidak memengaruhi tampilan APK dan tidak perlu di-rename massal agar perubahan tetap minimal dan aman.

## Detail Pekerjaan

1. **Android Launcher Label (`app/android/app/src/main/AndroidManifest.xml` baris 3):**
   - Ubah `android:label="myacrobat_app"` menjadi `android:label="AgriSign"`.
2. **Judul Aplikasi (`app/lib/main.dart` baris 44):**
   - Ubah `title: 'MyAcrobat'` menjadi `title: 'AgriSign'`.
3. **Halaman Login (`app/lib/src/features/auth/login_screen.dart`):**
   - Baris 73 (`AppBar.title`): ubah `'MyAcrobat'` menjadi `'AgriSign'`.
   - *(Catatan: Teks tombol submit `'Masuk ke MyAcrobat'` di baris 240 diubah menjadi `'Login'` pada Tiket 22.)*
4. **Halaman Daftar Dokumen (`app/lib/src/features/files/document_list_screen.dart` baris 67):**
   - Ubah `'MyAcrobat: Dokumen Mega.nz'` menjadi `'AgriSign'` (sekaligus menghapus referensi `Mega.nz` yang tidak relevan dengan AgriSign).

## Seam & Rencana Pengujian (TDD)

- **File Test:**
  - `app/test/syncro_auth_and_signature_sync_test.dart` (update assertion pada test #4 baris 366-369 dari `'MyAcrobat'` ke `'AgriSign'`).
  - `app/test/document_list_screen_test.dart` (verifikasi judul AppBar `'AgriSign'` tampil dan `'MyAcrobat'` tidak tampil).
- **Verifikasi:**
  - `flutter analyze --no-pub` -> 0 errors, 0 warnings.
  - `flutter test --no-pub` -> seluruh test lulus.

## Acceptance Criteria

- [x] Nama aplikasi APK di Android launcher (`AndroidManifest.xml`) adalah `AgriSign`.
- [x] Tidak ada lagi teks `MyAcrobat` yang tampil di UI (`main.dart`, `LoginScreen`, `DocumentListScreen`).
- [x] Semua unit/widget test di `app/test/` lulus.

## Comments

- **2026-11-23**: Tiket 18 selesai dieksekusi (`AndroidManifest.xml`, `main.dart`, `LoginScreen`, `DocumentListScreen`, serta update test). `flutter test --no-pub` lulus seluruhnya (+28 tests). `flutter analyze --no-pub` hanya melaporkan 5 `info` lint pra-eksisting di file lain (0 error/warning di file yang diubah).
