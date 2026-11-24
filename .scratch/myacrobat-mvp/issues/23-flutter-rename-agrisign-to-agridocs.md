# 23 â€” Ubah Nama Tampilan Aplikasi Flutter `AgriSign` menjadi `AgriDocs` (UI Only)

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Mengganti semua teks yang terlihat pengguna di `app/` dari `AgriSign` menjadi **`AgriDocs`**: nama aplikasi (Android/iOS/Web) dan judul di UI.

**Di luar scope:** URL server `https://syncro.saraswanti.co.id/agrisign` TIDAK diubah (route backend tetap `/agrisign`, lihat tiket 24); package `myacrobat_app`, kelas `MyAcrobat*`, dan tiket lama 17/18/22 tidak diubah.

## Detail Pekerjaan

1. **Nama aplikasi:**
   - `app/android/app/src/main/AndroidManifest.xml:3`: `android:label="AgriDocs"`.
   - `app/ios/Runner/Info.plist:10,18` (`CFBundleDisplayName`, `CFBundleName`): `AgriDocs`.
   - `app/web/manifest.json:2-3` (`name`, `short_name`): `AgriDocs`.
2. **Teks UI:** `app/lib/main.dart:44` (`title`), `app/lib/src/features/auth/login_screen.dart:74`, `app/lib/src/features/files/document_list_screen.dart:67`: `'AgriDocs'`.
3. **Test:** `app/test/document_list_screen_test.dart:86` dan `app/test/syncro_auth_and_signature_sync_test.dart:366,370` -> `find.text('AgriDocs')`. Test `api_client_and_models_test.dart:269` cukup ubah judul test; expected URL tetap `/agrisign`.
4. **Ikon:** gambar tidak berisi teks, tidak perlu diubah. Opsional: ganti nama `agrisign_icon.png` di root repo menjadi `agridocs_icon.png`.

## Verifikasi

- `flutter analyze --no-pub` -> tidak ada error/warning baru.
- `flutter test --no-pub` -> semua lulus.
- Cek `app/` tidak ada lagi teks `AgriSign` kecuali URL `/agrisign` dan judul test lama.

## Acceptance Criteria

- [x] Launcher Android, iOS, dan Web menampilkan `AgriDocs`.
- [x] Judul layar login dan daftar dokumen: `AgriDocs`.
- [x] Login & sinkronisasi tetap berjalan (URL server tidak berubah).
- [x] Semua test lulus.

