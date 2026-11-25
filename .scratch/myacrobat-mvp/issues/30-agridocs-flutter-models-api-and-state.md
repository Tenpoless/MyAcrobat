# 30 — Flutter Data Layer: Models Approval, API Client & Riverpod State

Status: ready-for-agent
Type: feature
Blocked by: 29

Repo target:
- `C:\laragon\www\MyAcrobat\app`

## Latar Belakang

Menyiapkan model data, metode HTTP pada `MyAcrobatApiClient`, dan state provider Riverpod di Flutter agar lapisan UI (Tiket 31 dan Tiket 32) dapat langsung mengonsumsi status approval per file, daftar antrean lintas folder (`my-tasks`), filter dokumen, serta endpoint manajemen kategori/folder/override khusus AgriDocs Admin.

## Ruang Lingkup & Spesifikasi

### 1. Models (`app/lib/src/models/`)
- **Tambah `document_approval.dart`**:
  - `ApprovalStepInfo` (`stepOrder`, `userId`, `userName`, `userPosition`, `stepLabel`, `status`, `signedAt`).
  - `DocumentApprovalInfo`:
    - `workflowId`, `status` (`pending` | `in_progress` | `completed` | `unconfigured`), `statusLabel`, `currentStepOrder`, `totalSteps`, `currentApproverUserId`, `currentApproverName`, `currentApproverPosition`, `isMyTurn`, `canSign`, `isCustomApproval`, `signedFileId`, `signedFileName`, `steps`.
    - Helper: `isCompleted`, `isInProgress`, `isPending`.
  - `DocumentCategoryConfig` (`id`, `name`, `description`, `driveFolderId`, `driveFolderName`, `isActive`, `steps`).
  - `AgriSignUserOption` (`id`, `name`, `username`, `position`, `agrisignRole`).
  - `MyPendingTaskItem` atau `VaultPdfFile` yang membawa `folderId` & `categoryName` (agar tugas lintas folder bisa langsung dibuka & ditandatangani tanpa mengubah folder path aktif di tab *Folder Drive*).
- **Update `vault_pdf_file.dart`**:
  - Tambah field opsional `DocumentApprovalInfo? approval`, `String? folderId`, `String? categoryName`.
  - Pertahankan parsing default bila backend lama / folder non-kategori mengembalikan `approval == null`.
- **Update `vault_folder.dart`**:
  - Update `VaultDirectoryListing` agar menyimpan `DocumentCategorySummary? category` (id, name, driveFolderId, driveFolderName) jika folder yang dibuka terhubung ke kategori dokumen.
- **Update `syncro_user.dart`**:
  - Tambah getter `bool get isAdmin => role.trim().toLowerCase() == 'admin';`.
- **Update `sign_document_result.dart`**:
  - Tambah field opsional `DocumentApprovalInfo? approval` hasil respons terbaru dari `POST /api/files/{id}/sign`.

### 2. API Client (`app/lib/src/api/myacrobat_api_client.dart`)
- Perbarui `fetchDirectory({String? search})`: parse `category` dan `approval` pada setiap `VaultPdfFile`.
- Tambah `fetchMyPendingTasks()` -> `GET /api/my-tasks` mengembalikan `List<VaultPdfFile>`.
- Perbarui `downloadPdfBytes(String fileId, {String? folderIdOverride, String? variant})` agar dapat mengunduh tugas dari tab *Giliran Saya* maupun memilih `?variant=source|signed`.
- Perbarui `signDocument(..., {String? folderIdOverride})` agar memakai `folderIdOverride ?? activeFolderId`.
- Tambah method manajemen Admin & detail workflow:
  - `fetchFileWorkflow(String fileId, {String? folderIdOverride})`
  - `fetchSelectableUsers()` -> `GET /api/users`
  - `fetchCategories()` -> `GET /api/categories`
  - `createCategory({required String name, String? description, required bool createNewFolder, String? driveFolderId, String? parentFolderId, required List<Map<String, dynamic>> steps})` -> `POST /api/categories`
  - `updateCategory(int categoryId, ...)` -> `PUT /api/categories/{id}`
  - `deleteCategory(int categoryId)` -> `DELETE /api/categories/{id}`
  - `updateFileWorkflow(String fileId, {String? folderId, required List<Map<String, dynamic>> steps})` -> `PUT /api/files/{id}/workflow`

### 3. Providers (`app/lib/src/features/files/document_list_provider.dart` & `app/lib/src/features/approval/approval_provider.dart`)
- Tambah `DocumentFilterMode` (`all`, `myTurn`, `inProgress`, `completed`) + `documentFilterProvider`.
- Perbarui `filteredDocumentsProvider` untuk menerapkan filter status approval di samping `searchQueryProvider`.
- Tambah `myPendingTasksProvider` (`AsyncNotifierProvider`) untuk daftar tugas *Giliran Saya* lintas folder + badge counter jumlah antrean TTD milik user login.
- Tambah `categoriesProvider` dan `selectableUsersProvider` (untuk layar Admin di Tiket 32) serta helper refresh sinkron setelah mutasi kategori/workflow/TTD.

## Verifikasi

- Jalankan `flutter test --no-pub` dan `flutter analyze --no-pub lib test` di `C:\laragon\www\MyAcrobat\app`.
- Update & tambah unit test di `app/test/`:
  - Parsing `VaultDirectoryListing` dengan `category` dan `files[].approval` + `steps`.
  - Parsing `fetchMyPendingTasks()` beserta `folderId` & `categoryName`.
  - Unit test payload & parsing endpoint `createCategory`, `updateCategory`, `updateFileWorkflow`, dan `downloadPdfBytes` dengan `folderIdOverride` + `variant`.
  - Unit test provider filter (`myTurn`, `inProgress`, `completed`) dan pembaruan counter *Giliran Saya*.
  - Update fake API client pada test existing agar tetap kompilasi dan lulus 100%.
