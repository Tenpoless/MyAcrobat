# 17 — Hapus Opsi Input Server & Kunci URL Server ke AgriSign Production

Status: resolved
Type: task

## Analisis Kondisi Saat Ini

Aplikasi Flutter di `app/` masih menyediakan pengaturan URL server secara manual dan membaca override dari `SharedPreferences`, sehingga kebutuhan agar aplikasi AgriSign **tidak memiliki opsi input server** belum terpenuhi:

1. **Default `API_BASE_URL` masih mengarah ke localhost (`app/lib/src/api/myacrobat_api_client.dart`):**
   - `MyAcrobatApiClient.defaultBaseUrl` menggunakan `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000')`.
2. **Tombol & Dialog Input Server pada `LoginScreen` (`app/lib/src/features/auth/login_screen.dart`):**
   - Terdapat tombol `Key('login_server_settings_button')` di header/AppBar yang memanggil `_openServerSettingsDialog()` (`Key('login_office_server_url_input')` & `Key('login_save_office_server_url_button')`).
3. **Tombol & Dialog Input Server pada `DocumentListScreen` (`app/lib/src/features/files/document_list_screen.dart`):**
   - Terdapat tombol `Key('office_server_settings_button')` di AppBar yang memanggil `_openOfficeServerSettingsDialog()` (`Key('office_server_url_input')` & `Key('save_office_server_url_button')`).
4. **Override URL dari `SharedPreferences` (`app/lib/src/features/files/document_list_provider.dart` & `app/lib/src/features/auth/auth_controller.dart`):**
   - `loadSavedOfficeServerUrl()` membaca key `myacrobat.office_server_url` saat `AuthController.restoreSession()` dan `DocumentListNotifier.build()` dijalankan. Jika perangkat pernah menyimpan URL lama, nilai tersebut akan menimpa `defaultBaseUrl`.
5. **Test Terdampak (`app/test/document_list_screen_test.dart`):**
   - Pengujian pada baris ~181–198 masih menguji interaksi `Key('office_server_settings_button')` dan `kOfficeServerUrlPrefKey`.

## Detail Pekerjaan

1. **Kunci Default Base URL (`app/lib/src/api/myacrobat_api_client.dart`):**
   - Ubah `defaultValue` pada `MyAcrobatApiClient.defaultBaseUrl` dari `'http://localhost:3000'` menjadi `'https://syncro.saraswanti.co.id/agrisign'`.
   - Tetap pertahankan `String.fromEnvironment('API_BASE_URL', ...)` agar kebutuhan test/staging via `--dart-define` tetap memungkinkan tanpa UI input server.
2. **Hapus Opsi Input Server di UI:**
   - Hapus `IconButton` `Key('login_server_settings_button')`, `_openServerSettingsDialog()`, serta import/helper terkait di `app/lib/src/features/auth/login_screen.dart`.
   - Hapus `IconButton` `Key('office_server_settings_button')`, `_openOfficeServerSettingsDialog()`, serta import/helper terkait di `app/lib/src/features/files/document_list_screen.dart`.
3. **Hapus Override URL dari `SharedPreferences`:**
   - Hapus `kOfficeServerUrlPrefKey`, `loadSavedOfficeServerUrl`, dan `saveOfficeServerUrl` dari `app/lib/src/features/files/document_list_provider.dart`.
   - Hapus pemanggilan `loadSavedOfficeServerUrl(...)` dari `DocumentListNotifier.build()` dan `AuthController.restoreSession()` (`app/lib/src/features/auth/auth_controller.dart`).
4. **Perbarui & Tambah Widget/Unit Test:**
   - Hapus/ganti skenario test dialog input server di `app/test/document_list_screen_test.dart`, pastikan `Key('office_server_settings_button')` tidak dirender.
   - Pastikan `Key('login_server_settings_button')` tidak dirender di `LoginScreen` (`app/test/syncro_auth_and_signature_sync_test.dart`).
   - Pastikan `MyAcrobatApiClient().baseUrl == 'https://syncro.saraswanti.co.id/agrisign'` secara default (`app/test/api_client_and_models_test.dart`).

## Acceptance Criteria

- [x] Tidak ada tombol maupun dialog untuk mengubah/menginput alamat server di `LoginScreen` maupun `DocumentListScreen`.
- [x] `MyAcrobatApiClient` secara default mengarah ke `https://syncro.saraswanti.co.id/agrisign` tanpa membaca override dari `SharedPreferences`.
- [x] `flutter analyze` (0 error/warning) dan seluruh `flutter test` di `app/test/` lulus.

## Comments

- Dibuat dari hasil analisis permintaan pengguna agar aplikasi Android AgriSign tidak memiliki opsi input server dan langsung terkunci ke server produksi.
