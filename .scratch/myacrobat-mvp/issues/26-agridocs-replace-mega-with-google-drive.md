# 26 — Ganti Seluruh Teks "Mega" / "Mega.nz" Menjadi "Google Drive" pada Aplikasi AgriDocs

Status: done
Type: task
Blocked by: -

Repo target:
- `C:\laragon\www\MyAcrobat` (`app`)

## Latar Belakang

Backend AgriDocs (`Modules/AgriSign`) sudah beralih dari Mega.nz ke Google Drive, namun masih terdapat beberapa teks UI dan fixture/deskripsi di aplikasi mobile Flutter `AgriDocs` yang menampilkan `"Mega.nz"`.

## Ruang Lingkup Perubahan

Telusuri seluruh codebase `AgriDocs` (`app/lib`, `app/test`, `app/pubspec.yaml`, dan `Modules/AgriSign` untuk memastikan tidak ada sisa teks user-facing `"Mega"` / `"Mega.nz"`) dan ganti menjadi `"Google Drive"`:

1. `app/lib/src/features/files/document_list_screen.dart`:
   - `'Memuat daftar dokumen PDF dari Mega.nz...'` -> `'Memuat daftar dokumen PDF dari Google Drive...'`
   - `'Belum ada dokumen PDF di folder Mega.nz.'` -> `'Belum ada dokumen PDF di folder Google Drive.'`
   - `'Unggah file PDF ke folder Mega.nz lalu muat ulang halaman ini.'` -> `'Unggah file PDF ke folder Google Drive lalu muat ulang halaman ini.'`
2. `app/lib/src/features/viewer/pdf_signing_screen.dart`:
   - `'File baru ${result.signedFile.name} telah disimpan ke Mega.nz.'` -> `'File baru ${result.signedFile.name} telah disimpan ke Google Drive.'`
   - `'Menyimpan & Mengunggah ke Mega.nz...'` -> `'Menyimpan & Mengunggah ke Google Drive...'`
3. `app/test/` (`api_client_and_models_test.dart`, `document_list_screen_test.dart`, `save_signed_document_flow_test.dart`) & `app/pubspec.yaml`:
   - Perbarui mock message / error message / description yang masih menyebut `Mega.nz` menjadi `Google Drive`.

## Verifikasi

- `flutter test --no-pub` di `C:\laragon\www\MyAcrobat\app`: 31/31 test lulus (`All tests passed!`).
