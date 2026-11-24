# 24 â€” Ubah Nama Tampilan Modul `AgriSign` menjadi `AgriDocs` di Web Syncro ERP (UI Only)

Status: done
Type: task
Blocked by: -

Repo target: `C:\laragon\www\syncro_erp`.

## Tujuan & Ruang Lingkup

Mengganti **semua teks yang terlihat pengguna** dari `AgriSign` menjadi **`AgriDocs`**: nama modul di halaman atur role, hub mobile, judul halaman modul, dan pesan yang tampil.

**Di luar scope (JANGAN diubah):** folder/namespace `Modules\AgriSign`, nama class, route & URL (`/agrisign`, `/api/v1/agrisign`), nama route, alias modul, key config `agrisign`, `module_key` di DB, env `AGRISIGN_*`, nama token Sanctum, `modules_statuses.json`, `bootstrap/providers.php`, `composer.json`. Dengan begitu tidak ada migrasi data, tidak ada perubahan `.env`, dan APK lama tetap berjalan.

## Hasil Analisis

Halaman atur role membaca label dari `config('module-roles.modules')` (`UserController`, `PortalRolesController`), sehingga cukup mengubah satu label di config.

## Detail Pekerjaan

1. `config/module-roles.php:142`: `'label' => 'AgriDocs (PDF Reader & Quick E-Signature - Google Drive)'` (tampil di atur role).
2. `Modules/MobileHub/app/Http/Controllers/Api/MobileHubAuthController.php:39`: label modul menjadi `'AgriDocs (PDF Reader & Quick E-Signature - Google Drive)'` (tampil di aplikasi mobile hub).
3. `Modules/AgriSign/resources/views/index.blade.php`: `<title>` (baris 7) dan `<h1>` (baris 18) menjadi `AgriDocs`.
4. `Modules/AgriSign/app/Services/GoogleDriveVaultService.php:294`: teks pesan `Kredensial Google Drive AgriSign belum dikonfigurasi` -> `AgriDocs`; nama env di dalam pesan tetap `AGRISIGN_*`.
5. `Modules/AgriSign/module.json` & `composer.json`: field `description` -> `AgriDocs ...` (nama/alias tidak berubah).
6. `app/Http/Controllers/ModuleHubController.php:141`: komentar blok `'name' => 'AgriSign'` -> `'AgriDocs'` agar saat diaktifkan nanti sudah benar.
7. Test: `tests/Feature/AgriSignModuleApiTest.php` â€” teks tampilan seperti `'Dokumen AgriSign Google Drive'`, nama user dummy; assert label bila ada. Nama class/URL/module_key test tidak berubah.

## Verifikasi

- `php artisan test --filter=AgriSign` lulus.
- Buka Admin > User/Role: modul tampil sebagai `AgriDocs (...)`; halaman `/agrisign` menampilkan judul `AgriDocs`.
- `git grep -n "AgriSign"` pada teks yang terlihat pengguna (string, blade) -> 0 hasil; sisa hanya namespace/class/route/env.

## Acceptance Criteria

- [x] Nama modul di halaman atur role & mobile hub: `AgriDocs`.
- [x] Judul dan header halaman modul web: `AgriDocs`.
- [x] Pesan error yang tampil menyebut `AgriDocs`.
- [x] Route, DB, `.env`, dan namespace tidak berubah; semua test lulus.

