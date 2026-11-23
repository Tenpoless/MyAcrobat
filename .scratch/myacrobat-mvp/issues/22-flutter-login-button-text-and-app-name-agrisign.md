# 22 — Ubah Teks Tombol Login menjadi `Login` & Nama Aplikasi Menjadi `AgriSign`

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Memperbarui teks tombol submit pada halaman login dari `'Masuk ke MyAcrobat'` menjadi **`'Login'`** serta memastikan nama aplikasi (`app name` / `display name`) di konfigurasi platform APK/Flutter diubah dari `myacrobat` / `myacrobat_app` menjadi **`AgriSign`**.

## Detail Pekerjaan

1. **Teks Tombol Submit Login (`app/lib/src/features/auth/login_screen.dart` baris 240):**
   - Ubah label tombol saat tidak loading dari `'Masuk ke MyAcrobat'` menjadi **`'Login'`**.
2. **Nama Aplikasi Android (`app/android/app/src/main/AndroidManifest.xml` baris 3):**
   - Pastikan `android:label="myacrobat_app"` diubah menjadi **`android:label="AgriSign"`** (ini adalah nama aplikasi yang tampil di launcher HP Android saat APK diinstal).
3. **Nama Aplikasi Platform Lain (konsistensi multi-platform):**
   - `app/ios/Runner/Info.plist`: ubah `CFBundleDisplayName` (`Myacrobat App`) dan `CFBundleName` (`myacrobat_app`) menjadi **`AgriSign`**.
   - `app/web/manifest.json`: ubah `"name"` dan `"short_name"` (`myacrobat_app`) menjadi **`"AgriSign"`**.
   - *(Opsional — konfirmasi jika diperlukan)*: `applicationId` di `app/android/app/build.gradle.kts` baris 19 masih `"com.example.myacrobat_app"`. Mengubah `applicationId` akan membuat APK terinstal sebagai aplikasi baru yang terpisah dari APK lama, sehingga dibiarkan tetap kecuali user meminta ganti package ID.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test:**
  - Pada `LoginScreen`, pastikan tombol `Key('login_submit_button')` menampilkan teks `'Login'` dan tidak menampilkan `'Masuk ke MyAcrobat'`.
- **Verifikasi:**
  - `flutter analyze --no-pub` -> 0 errors, 0 warnings.
  - `flutter test --no-pub` -> seluruh test lulus.

## Acceptance Criteria

- [x] Tombol submit pada `LoginScreen` menampilkan teks `'Login'` (bukan `'Masuk ke MyAcrobat'`).
- [x] Nama aplikasi APK di Android (`AndroidManifest.xml` `android:label`) adalah `'AgriSign'`.
- [x] Nama aplikasi di `ios/Runner/Info.plist` dan `web/manifest.json` adalah `'AgriSign'`.
- [x] Seluruh unit/widget test pada `app/test/` lulus.
