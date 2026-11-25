# 29 — Backend Workflow Engine, Strict Sequential Signing & API Endpoints

Status: ready-for-agent
Type: feature
Blocked by: 28

Repo target:
- `C:\laragon\www\syncro_erp` (`Modules/AgriSign`)

## Latar Belakang

Di atas skema DB dan operasi Drive dari Tiket 28, backend perlu menyediakan logika workflow berjenjang (`AgriSignWorkflowService`) serta API endpoint untuk:
- Manajemen Config Approval & Pembuatan Folder Kategori (khusus **AgriDocs Admin**).
- Auto-apply template kategori pada file di folder terkait dan override approval per file (khusus **AgriDocs Admin**).
- Penegakan TTD berurutan ketat (*strict sequential*), penempelan TTD bertahap di atas `_signed.pdf` progresif dalam folder yang sama, serta endpoint daftar tugas lintas folder (`my-tasks`).

## Ruang Lingkup & Spesifikasi

### 1. `AgriSignWorkflowService.php` (`Modules/AgriSign/app/Services/AgriSignWorkflowService.php`)
- **`syncFolderWorkflows(string $folderId, array $driveFiles, ?User $viewer): array`**:
  - Cari `DocumentCategory` aktif yang memetakan `drive_folder_id = $folderId`.
  - Jika folder terhubung ke kategori:
    - Identifikasi pasangan file sumber & `signed_drive_file_id` yang tercatat di `agrisign_document_workflows`, lalu **gabungkan menjadi satu entri file logis** pada daftar response (membawa `fileId` sumber, `signedFileId`, dan `effectiveFileId = signed_drive_file_id ?? drive_file_id`) sehingga user tidak bingung memilih antara file polos vs `_signed.pdf`.
    - Untuk file sumber PDF baru (yang bukan merupakan `signed_drive_file_id` dan belum punya record workflow): auto-instantiate `DocumentWorkflow` + salin baris `templateSteps` menjadi `DocumentApprovalStep` (step 1 = `current`, sisanya = `waiting`; jika template kosong -> `completed` atau `unconfigured`).
  - Lampirkan blok `approval` terstruktur ke setiap file:
    - `workflowId`, `status` (`pending` | `in_progress` | `completed` | `unconfigured`), `statusLabel` (mis. `"Menunggu: Budi Santoso (2/3)"`, `"Selesai TTD (3/3)"`), `currentStepOrder`, `totalSteps`, `currentApprover` (`{ userId, name, position }`), `isMyTurn` (bool), `canSign` (bool), `isCustomApproval` (bool), `signedFileId`, `signedFileName`, `steps` (`[ { stepOrder, userId, name, position, stepLabel, status, signedAt } ]`).
- **`syncCategoryTemplateToPendingWorkflows(DocumentCategory $category): void`**:
  - Ketika Admin mengubah template step kategori, sinkronkan workflow di folder tersebut yang masih `status = 'pending'` dan `is_custom_approval = false`.
- **`updateFileWorkflowSteps(string $fileId, string $folderId, array $steps): DocumentWorkflow`**:
  - Untuk override approval khusus 1 file (`is_custom_approval = true`).
  - Pertahankan step yang sudah `signed` dengan `step_order` awal yang sama; validasi step baru tidak menghapus/mengubah step yang sudah ditandatangani, perbarui step yang belum selesai, lalu hitung ulang `current_step_order` dan `status` (`completed` bila seluruh step `signed`, atau `in_progress` / `pending` menunjuk step belum `signed` pertama sebagai `current`).
- **`resolveDownloadTarget(string $requestedFileId, ?string $variant = null): array`**:
  - Tentukan target Drive ID dan apakah perlu meneruskan `folderId` workflow: default (tanpa `variant=source`) mengembalikan `signed_drive_file_id` bila sudah ada agar penanda tangan berikutnya otomatis membuka PDF dengan TTD sebelumnya sudah menempel. Jika `variant=source`, kembalikan file sumber asli; jika `variant=signed`, wajib ada `signed_drive_file_id`.
- **`advanceAfterSign(DocumentWorkflow $workflow, User $signer, array $uploadedSignedFile): DocumentWorkflow`**:
  - Tandai step aktif sebagai `signed` (`signed_at = now()`, `signed_by_user_id = $signer->id`), simpan `signed_drive_file_id` & `signed_file_name`.
  - Jika masih ada step berikutnya (`step_order > current_step_order`), ubah step berikutnya ke `current`, perbarui `current_step_order` & `status = 'in_progress'`.
  - Jika tidak ada step lagi, set `status = 'completed'`, `current_step_order = null`, `completed_at = now()`.

### 2. Update `AgriSignFileController.php`
- **`index()`**:
  - Resolve user dari Sanctum bearer token (`resolveRequestUser`) untuk menghitung `isMyTurn` dan `canSign`.
  - Panggil `syncFolderWorkflows()` untuk folder aktif.
  - Kembalikan tambahan metadata `category` (id, name, driveFolderId, driveFolderName) jika folder terdaftar ke kategori, serta `files` dengan field `approval` dan `folderId`.
  - Pertahankan kompatibilitas penuh (*backward compatible*) untuk folder yang belum punya kategori/config approval (`approval = null`, file `_signed.pdf` tidak digabung paksa).
- **`download()`**:
  - Terima query `variant` (`source` | `signed` opsional). Gunakan `resolveDownloadTarget()` agar membuka kartu dokumen berkategori otomatis menyajikan PDF progres terbaru.
- **`sign()`**:
  - Cari workflow berdasarkan `fileId` (baik dikirim `drive_file_id` maupun `signed_drive_file_id`).
  - Jika workflow ditemukan:
    - Wajib user terautentikasi (`401`).
    - Jika `status === 'completed'` -> `409 Conflict` (`"Seluruh tahap tanda tangan dokumen ini sudah selesai."`).
    - Jika step aktif bukan milik `$user->id` -> `403 Forbidden` (`"Saat ini giliran [Nama Approver] (Step X/Y), belum giliran Anda."`) — **strict sequential, termasuk Admin tidak bypass**.
    - Unduh basis PDF dari `signed_drive_file_id ?? drive_file_id`, tempel TTD via `PdfSignatureEmbedderService`, simpan ke Drive di folder yang sama via `GoogleDriveVaultService::upsertSignedPdf()`, lalu jalankan `advanceAfterSign()`, dan kembalikan `signedFile` + objek `approval` terbaru.

### 3. `AgriSignCategoryController.php` & Rute API (`Modules/AgriSign/routes/api.php`)
Daftarkan di ketiga prefix rute (`api/v1/agrisign`, `api/agrisign`, `agrisign/api`):
- **`auth:sanctum`** (semua role AgriDocs):
  - `GET my-tasks`: query `DocumentApprovalStep` di mana `user_id = auth()->id()` dan `status = 'current'`, beserta detail workflow, kategori/folder asal (`driveFolderId`, `categoryName`), dan daftar `steps`.
  - `GET files/{fileId}/workflow`: kembalikan status workflow & timeline step dokumen tersebut (plus `folderId` jika di-pass).
- **`auth:sanctum` + `agrisign.role:Admin`** (eksklusif AgriDocs Admin):
  - `GET users`: daftar user aktif (`id`, `name`, `username`, `position`, `agrisignRole`) untuk dropdown pemilih approver.
  - `GET categories`: daftar kategori + folder Drive + template steps.
  - `POST categories`: validasi input (`name`, `description`, `createNewFolder` bool, `driveFolderId` bila existing, `parentFolderId` opsional, `steps[]` berisi `userId` & `stepLabel` opsional). Jika `createNewFolder = true`, panggil `$vault->createFolder(...)` terlebih dulu lalu simpan kategori + template steps dalam DB transaction.
  - `PUT categories/{category}`: update metadata kategori, mapping folder (bila berubah), dan ganti `templateSteps` + panggil `syncCategoryTemplateToPendingWorkflows()`.
  - `DELETE categories/{category}`: hapus kategori (tidak menghapus file/folder di Google Drive).
  - `PUT files/{fileId}/workflow`: validasi `steps[]` (`userId`, `stepLabel` opsional) + `folderId` opsional, simpan custom approval per-file (`is_custom_approval = true`), kembalikan objek `approval` terbaru.

## Verifikasi

- Jalankan `php artisan test --filter=AgriSign` di `C:\laragon\www\syncro_erp`.
- Tambahkan Feature Tests (`tests/Feature/AgriSignWorkflowApiTest.php`):
  - Non-Admin (`Signer` / `Viewer` / user global tanpa `agrisign = Admin`) ditolak `403` saat akses `GET/POST/PUT/DELETE categories`, `GET users`, dan `PUT files/{id}/workflow`.
  - Admin dapat membuat 4 kategori dokumen berbeda + buat folder baru di Drive -> masing-masing punya config step berbeda.
  - Listing folder kategori menginisiasi workflow template ke file baru & menggabung pasangan source + `_signed.pdf`.
  - Simulasi TTD berjenjang 3 step pada 1 folder: Step 2 ditolak `403` sebelum Step 1 selesai; Admin pun ditolak `403` jika bukan gilirannya; Step 1 -> upload `_signed.pdf`; Step 2 -> download `_signed.pdf` Step 1 dan replace di folder sama; Step 3 -> workflow menjadi `completed`.
  - Override approval per-file (`PUT files/{id}/workflow`) mengubah step file tersebut (`isCustomApproval: true`) tanpa mengubah file lain atau template kategori.
  - `GET my-tasks` hanya mengembalikan dokumen yang sedang `current` di user yang login lintas beberapa folder kategori.
