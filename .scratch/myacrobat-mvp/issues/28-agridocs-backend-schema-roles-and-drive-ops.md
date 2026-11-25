# 28 — Backend Fondasi Approval: Skema DB, Models, Role Admin & Operasi Folder/Replace Drive

Status: ready-for-agent
Type: feature
Blocked by: -

Repo target:
- `C:\laragon\www\syncro_erp` (`Modules/AgriSign`, `bootstrap/app.php`)
- `C:\laragon\www\MyAcrobat\docs\apps-script\Code.gs`

## Latar Belakang

Menyiapkan lapisan fondasi backend dan Google Drive bridge sebelum logika workflow berjenjang dan UI dibangun: struktur tabel database untuk kategori dokumen, template approval per kategori, state workflow per file, serta kemampuan membuat subfolder Google Drive dan memperbarui file `_signed.pdf` progresif dalam satu folder tanpa menumpuk duplikat.

## Ruang Lingkup & Spesifikasi

### 1. Google Apps Script (`C:\laragon\www\MyAcrobat\docs\apps-script\Code.gs`)
Tambahkan 2 action pada `doPost(e)`:
- **`action = 'createFolder'`**:
  - Parameter JSON: `{ secret, action: 'createFolder', parentFolderId, name }`.
  - Validasi `name` tidak kosong; buat subfolder via `folder_(body.parentFolderId).createFolder(name)`.
  - Kembalikan `{ id, name, modifiedTime }`.
- **`action = 'replace'`**:
  - Parameter JSON: `{ secret, action: 'replace', folderId, fileName, base64, replaceFileId }`.
  - Unggah blob PDF baru ke `folder_(body.folderId).createFile(blob)`.
  - Jika `body.replaceFileId` terisi, pindahkan file lama ke trash dengan `DriveApp.getFileById(body.replaceFileId).setTrashed(true)` (dibungkus try/catch aman bila file sudah tidak ada) sehingga folder tidak penuh dengan `_signed_2`, `_signed_3`.
  - Kembalikan `{ id, name, size, modifiedTime }`.

### 2. Migrasi & Eloquent Models (`C:\laragon\www\syncro_erp\Modules\AgriSign`)
- Aktifkan `$this->loadMigrationsFrom(module_path($this->name, 'database/migrations'));` pada `AgriSignServiceProvider::boot()`.
- Buat migrasi `Modules/AgriSign/database/migrations/2026_11_24_000001_create_agrisign_approval_tables.php`:
  1. `agrisign_document_categories`:
     - `id`, `name` (string), `description` (nullable text), `drive_folder_id` (unique string), `drive_folder_name` (string), `is_active` (boolean default true), `created_by` (nullable unsignedBigInteger FK `users`), `timestamps`.
  2. `agrisign_approval_template_steps`:
     - `id`, `category_id` (FK `agrisign_document_categories` cascadeOnDelete), `step_order` (unsignedSmallInteger), `user_id` (FK `users`), `step_label` (nullable string), `timestamps`, unique `(category_id, step_order)`.
  3. `agrisign_document_workflows`:
     - `id`, `category_id` (nullable FK `agrisign_document_categories` nullOnDelete), `drive_file_id` (unique string), `drive_folder_id` (string indexed), `file_name` (string), `signed_drive_file_id` (nullable string), `signed_file_name` (nullable string), `status` (string: `pending` | `in_progress` | `completed`), `current_step_order` (nullable unsignedSmallInteger), `is_custom_approval` (boolean default false), `completed_at` (nullable timestamp), `timestamps`.
  4. `agrisign_document_approval_steps`:
     - `id`, `workflow_id` (FK `agrisign_document_workflows` cascadeOnDelete), `step_order` (unsignedSmallInteger), `user_id` (FK `users`), `step_label` (nullable string), `status` (string: `waiting` | `current` | `signed`), `signed_at` (nullable timestamp), `signed_by_user_id` (nullable unsignedBigInteger FK `users`), `timestamps`, unique `(workflow_id, step_order)`.
- Buat 4 Model di `Modules/AgriSign/app/Models/`:
  - `DocumentCategory.php` (relasi `templateSteps()`, `workflows()`)
  - `ApprovalTemplateStep.php` (relasi `category()`, `user()`)
  - `DocumentWorkflow.php` (relasi `category()`, `steps()`, `currentStep()`)
  - `DocumentApprovalStep.php` (relasi `workflow()`, `user()`, `signedBy()`)

### 3. Role Middleware AgriDocs Admin (`syncro_erp`)
- Buat `Modules/AgriSign/app/Http/Middleware/AgriSignRoleMiddleware.php` (pola seragam dengan `AgriFlowRoleMiddleware`): memeriksa `$user->moduleRole('agrisign')`, mengembalikan HTTP `403` untuk JSON/API bila bukan role yang diizinkan (mis. `agrisign.role:Admin`).
- Daftarkan alias `'agrisign.role' => \Modules\AgriSign\Http\Middleware\AgriSignRoleMiddleware::class` di `bootstrap/app.php`.
- Pastikan `AgriSignAuthController::formatUserProfile()` dan pemeriksaan `isAgriDocsAdmin` konsisten bahwa role config approval hanya milik user dengan role modul `agrisign = 'Admin'`.

### 4. `GoogleDriveVaultService.php` (`Modules/AgriSign/app/Services/GoogleDriveVaultService.php`)
- Tambah `createFolder(string $name, ?string $parentFolderId = null): array`:
  - Apps Script mode: `POST` `action=createFolder` ke `$appsScriptUrl`.
  - Drive v3 API mode: `POST https://www.googleapis.com/drive/v3/files?fields=id,name,modifiedTime&supportsAllDrives=true` dengan `mimeType: 'application/vnd.google-apps.folder'` dan `parents: [$parent]`.
  - Mengembalikan `['folderId' => ..., 'name' => ..., 'updatedAt' => ...]`.
- Tambah `upsertSignedPdf(string $sourceFileId, string $targetSignedName, string $signedPdfBytes, ?string $existingSignedFileId = null, ?string $folderId = null): array`:
  - Jika `$existingSignedFileId` null/kosong: buat file PDF `_signed.pdf` baru pada `$folderId` (menggunakan logika multipart Drive v3 / `action=upload` Apps Script).
  - Jika `$existingSignedFileId` sudah ada:
    - Drive v3 API mode: `PATCH https://www.googleapis.com/upload/drive/v3/files/{$existingSignedFileId}?uploadType=media&fields=id,name,size,modifiedTime&supportsAllDrives=true` (`Content-Type: application/pdf`).
    - Apps Script mode: `POST` `action=replace` dengan `replaceFileId = $existingSignedFileId` dan `fileName = $targetSignedName`.

## Verifikasi

- Jalankan `php artisan test --filter=AgriSign` di `C:\laragon\www\syncro_erp`.
- Unit test baru di `tests/Unit/AgriSignGoogleDriveVaultTest.php`:
  - `createFolder` via Google Drive v3 API & Google Apps Script (`Http::fake`).
  - `upsertSignedPdf` mode baru (`upload`) dan mode perbarui (`PATCH` media di Drive v3 & `action=replace` di Apps Script).
- Verifikasi migrasi berjalan bersih pada SQLite in-memory test dan seluruh relasi model (`DocumentCategory`, `DocumentWorkflow`, `DocumentApprovalStep`).
