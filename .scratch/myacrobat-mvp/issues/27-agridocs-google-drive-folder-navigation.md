# 27 — Navigasi Folder & Subfolder Google Drive (Opsi A) pada AgriDocs

Status: done
Type: feature
Blocked by: -

Repo target:
- `C:\laragon\www\syncro_erp` (`Modules/AgriSign`)
- `C:\laragon\www\MyAcrobat` (`app`)
- Google Apps Script (`Code.gs` Web App eksternal — perlu re-deploy oleh admin)

## Latar Belakang

Saat ini `AgriDocs` hanya membaca file PDF langsung di root folder (`AGRISIGN_GOOGLE_DRIVE_FOLDER_ID`) dan belum menampilkan subfolder Google Drive. User membutuhkan navigasi folder interaktif (mirip Google Drive, **Opsi A**) agar dapat menelusuri subfolder, melihat daftar PDF di dalamnya, serta membuka dan menandatangani PDF di dalam subfolder tersebut.

## Desain & Ruang Lingkup

### 1. Google Apps Script (`Code.gs`)
- **`action=list`** (menerima `folderId` opsional, fallback ke root folder default):
  - Mengembalikan daftar subfolder (`folders`: `{ id, name, modifiedTime }`) via `folder.getFolders()` **dan** daftar PDF (`files`: `{ id, name, size, modifiedTime }`) via `folder.getFilesByType(MimeType.PDF)`.
- **`action=download`** & **`action=upload`**:
  - `download` mengambil file langsung via `DriveApp.getFileById(fileId)` (tetap bekerja untuk file di subfolder).
  - `upload` menggunakan `folderId` dari payload (jika ada, agar `_signed.pdf` tersimpan di folder yang sama dengan file sumber), fallback ke root folder.
- Catatan: sertakan referensi kode `Code.gs` di dokumentasi/tiket agar admin mudah deploy versi baru Web App GAS.

### 2. Backend (`C:\laragon\www\syncro_erp\Modules\AgriSign`)
- **`GoogleDriveVaultService.php`:**
  - Tambahkan dukungan parameter opsional `?string $folderId = null` pada listing isi folder (`listFolderContents(?string $folderId = null): array` yang mengembalikan `['folders' => ..., 'files' => ...]`, sambil tetap mempertahankan kompatibilitas `listPdfFiles(?string $folderId = null)`).
  - Dukung listing `folders` (`mimeType = 'application/vnd.google-apps.folder'`) baik untuk mode **Google Apps Script** maupun **Drive v3 API**.
  - Perbarui `downloadPdf(string $fileId, ?string $folderId = null)` dan `uploadSignedPdf(string $sourceFileId, string $signedPdfBytes, ?string $folderId = null)` agar validasi/listing mengacu ke `$folderId` aktif (tidak selalu root) dan hasil `_signed.pdf` diunggah ke folder tersebut.
- **`AgriSignFileController.php`:**
  - `index(Request $request)`: terima query `folderId` (opsional) dan kembalikan JSON:
    ```json
    {
      "currentFolderId": "...",
      "folders": [{ "folderId": "...", "name": "...", "updatedAt": "..." }],
      "files": [...]
    }
    ```
    (Filter `search` tetap berlaku untuk nama folder dan nama file PDF pada folder aktif.)
  - `download(Request $request, string $fileId)` & `sign(Request $request, string $fileId)`: teruskan `folderId` opsional (query/body) ke `GoogleDriveVaultService`.
- **Unit/Feature Tests (`Modules/AgriSign/tests`):**
  - Uji `GET /api/v1/agrisign/files?folderId=...` mengembalikan `folders` + `files` (mode Apps Script & Drive API).
  - Uji `download` dan `sign` untuk file di dalam subfolder (`folderId` diteruskan sampai upload).

### 3. Mobile App (`C:\laragon\www\MyAcrobat\app`)
- **Models & API Client (`app/lib/src/models/` & `app/lib/src/api/myacrobat_api_client.dart`):**
  - Tambahkan model `VaultFolder` (`folderId`, `name`, `updatedAt`) dan `VaultDirectoryListing` (`currentFolderId`, `folders`, `files`).
  - Perbarui `MyAcrobatApiClient` untuk `fetchDirectory({String? folderId, String? search})` (kompatibel jika backend lama hanya mengembalikan `files`), serta parameter opsional `folderId` di `downloadPdfBytes()` dan `signDocument()`.
- **State & UI (`app/lib/src/features/files/document_list_provider.dart`, `document_list_screen.dart`, `pdf_signing_screen.dart`):**
  - Simpan stack navigasi folder (`root` -> `Subfolder A` -> `Subfolder B`) di provider/state.
  - Tampilkan breadcrumb / tombol kembali ke folder induk saat berada di dalam subfolder (termasuk dukungan tombol Back Android / `PopScope` agar kembali ke folder induk terlebih dahulu sebelum keluar aplikasi).
  - Tampilkan item folder (ikon folder + nama + jumlah/tap untuk masuk) di atas daftar file PDF.
  - Teruskan `currentFolderId` ke `PdfSigningScreen` saat membuka/menandatangani file di subfolder agar `download` & `sign` sukses dan daftar folder aktif ikut ter-refresh setelah simpan.
- **Flutter Tests (`app/test/`):**
  - Uji parsing `folders` + `files` di `api_client_and_models_test.dart`.
  - Uji navigasi masuk ke subfolder, breadcrumb/back ke root, dan pencarian di `document_list_screen_test.dart`.

## Verifikasi

- `php artisan test --filter=AgriSign` di `C:\laragon\www\syncro_erp` lulus.
- `flutter test --no-pub` di `C:\laragon\www\MyAcrobat\app` lulus.
- Uji manual dengan deploy ulang `Code.gs` GAS: membuka subfolder dari `AgriDocs`, membuka PDF di subfolder, menandatangani, dan memastikan `_signed.pdf` tersimpan di subfolder yang sama.
