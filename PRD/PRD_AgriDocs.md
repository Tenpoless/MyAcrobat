# Product Requirements Document (PRD): AgriDocs (MyAcrobat)

**Versi Dokumen:** 2.0 (Current Production Baseline + Sequential Approval Workflow s/d Tiket 32)  
**Tanggal:** 25 November 2026  
**Status:** Disetujui / Siap Eksekusi (Tiket 28–32)  
**Nama Aplikasi:** **AgriDocs** (repo `MyAcrobat/app`, modul backend `syncro_erp/Modules/AgriSign`)  
**Endpoint Produksi:** `https://syncro.saraswanti.co.id/agrisign`

---

## 1. Latar Belakang & Evolusi Produk

**AgriDocs** (sebelumnya bernama *MyAcrobat* / *AgriSign*) adalah aplikasi pembaca dan penandatangan dokumen PDF (*PDF Reader & Sequential E-Signature*) yang terintegrasi penuh dengan **Syncro ERP** (autentikasi, hak akses modul, data jabatan, spesimen tanda tangan) dan **Google Drive** sebagai penyimpanan dokumen terpusat.

### Evolusi Arsitektur (v1.0 $\rightarrow$ v2.0)
- **Fase MVP (Tiket 01–27 — Sudah Terimplementasi):**
  - Migrasi backend dari prototipe Node.js + Mega.nz menjadi modul Laravel **`Modules/AgriSign`** di dalam **`syncro_erp`** dengan **PostgreSQL** bersama dan autentikasi **Laravel Sanctum**.
  - Migrasi penyimpanan cloud dari Mega.nz ke **Google Drive** (mendukung **Google Drive API v3** maupun **Google Apps Script Web App Bridge** `Code.gs`), lengkap dengan navigasi subfolder (*breadcrumb*) dan *auto-save* tanda tangan dua arah (`users.signature_path` + cache lokal perangkat).
  - Rebranding aplikasi client Flutter menjadi **AgriDocs** dengan APK rilis `AgriDocs.apk` dan izin `INTERNET` aktif di `AndroidManifest.xml`.
- **Fase Approval Berjenjang (Tiket 28–32 — Target PRD Ini):**
  - Mengubah alur tanda tangan dari *ad-hoc quick sign* menjadi **approval berjenjang berbasis kategori dokumen & folder Google Drive** untuk menghilangkan kebutuhan kirim-mengirim file ulang secara manual dan memudahkan user mengetahui giliran tanda tangannya tanpa membuka file satu per satu.

---

## 2. Tujuan Bisnis & Pemecahan Masalah (Tiket 28–32)

| Masalah Saat Ini | Solusi pada AgriDocs v2.0 (Tiket 28–32) |
| :--- | :--- |
| User harus mengirim ulang file hasil TTD ke penanda tangan berikutnya secara manual. | File sumber & hasil TTD (`_signed.pdf`) berada dalam **1 folder kategori**, dan setiap TTD berikutnya otomatis menempel di atas `_signed.pdf` progresif yang sama (*replace / in-place update*). |
| User harus membuka file atau folder satu per satu untuk tahu apakah sudah gilirannya TTD. | Kartu dokumen menampilkan **status & posisi user aktif** (`GILIRAN ANDA TTD`, `Menunggu: Nama (Step X/Y)`, `Selesai TTD`) ditambah tab khusus **`Giliran Saya (N)`** lintas seluruh folder. |
| Tidak ada pemisahan aturan approval antar jenis dokumen. | **Config Approval per Kategori/Tipe Dokumen** (mis. 4 tipe dokumen = 4 config approval) yang masing-masing terhubung ke **1 folder Google Drive** + fitur **Tambah Folder Baru**. |
| Pengaturan approval rawan diubah oleh user biasa. | Manajemen Config Approval, pembuatan folder kategori, dan override approval per file dikunci eksklusif untuk role **AgriDocs Admin** (`moduleRole('agrisign') === 'Admin'`). |
| Terkadang satu file butuh pengecualian penanda tangan dibanding template foldernya. | **Override Approval Per-File** oleh AgriDocs Admin (`is_custom_approval = true`) yang mengunci step yang sudah ditandatangani (`signed`) dan membolehkan perubahan pada step yang belum selesai. |

---

## 3. Arsitektur Teknis Terkini

### 3.1 Komponen Sistem
1. **Frontend Mobile (`C:\laragon\www\MyAcrobat\app`)**:
   - **Framework:** Flutter + Riverpod (`StateNotifierProvider` / `AsyncNotifierProvider`), `dio`, `printing`, `signature`, `path_provider`, `shared_preferences`.
   - **Target Base URL:** `https://syncro.saraswanti.co.id/agrisign` (prefiks `/agrisign/api/*`).
   - **Output Build:** `flutter build apk` menghasilkan `app-release.apk` yang otomatis disalin Gradle ke `AgriDocs.apk`.
2. **Backend Modul (`C:\laragon\www\syncro_erp\Modules\AgriSign`)**:
   - **Framework:** Laravel Modular (`nwidart/laravel-modules`), Laravel Sanctum (`auth:sanctum`), Spatie + `module_role_assignments` (`module_key = 'agrisign'`).
   - **PDF Embedding Engine:** `PdfSignatureEmbedderService` (menempelkan PNG tanda tangan ter-normalisasi ke koordinat PDF secara permanen / *flattened*).
   - **Google Drive Gateway:** `GoogleDriveVaultService` (mendukung mode Drive v3 Service Account/OAuth2 dan mode Google Apps Script Web App).
   - **Workflow Engine (Tiket 29):** `AgriSignWorkflowService` untuk sinkronisasi folder-kategori, auto-instansiasi step, penegakan urutan ketat (*strict sequential*), dan resolusi basis PDF progresif.
3. **Google Drive Bridge (`C:\laragon\www\MyAcrobat\docs\apps-script\Code.gs`)**:
   - Web App Google Apps Script dengan `SECRET` (`AGRISIGN_GOOGLE_APPS_SCRIPT_SECRET`).
   - Mendukung `list`, `download`, `upload`, serta (Tiket 28) **`createFolder`** dan **`replace`** (unggah PDF baru lalu *trash* `_signed.pdf` perantara sebelumnya agar tidak menumpuk duplikat).

### 3.2 Kebijakan Konvensi & Kompatibilitas
- Key `.env` (`AGRISIGN_*`), `module_key` (`'agrisign'`), prefiks rute (`/agrisign/api/*`, `/api/agrisign/*`, `/api/v1/agrisign/*`), dan namespace `Modules\AgriSign` dipertahankan.
- Folder Google Drive yang **belum** dipetakan ke kategori dokumen tetap berjalan dengan perilaku *backward-compatible* (`approval = null`, *quick sign* tetap tersedia bagi `Signer`/`Admin`).

---

## 4. Peran Pengguna & Matriks Hak Akses

Role dibaca dari tabel `module_role_assignments` dengan `module_key = 'agrisign'`:

| Role | Definisi | Baca & Unduh PDF | Tanda Tangan PDF | Kelola Config Approval, Tambah Folder & Override File |
| :--- | :--- | :---: | :---: | :---: |
| **AgriDocs Admin** (`Admin`) | Administrator modul AgriDocs (`agrisign = 'Admin'` ketat, **tanpa** fallback role global non-modul) | Ya | Ya *(wajib ikut urutan jika workflow aktif)* | **Ya (Eksklusif)** |
| **Signer** (`Signer`) | Penanda tangan dokumen | Ya | Ya *(jika gilirannya pada workflow aktif, atau bebas di folder non-kategori)* | Tidak (`403 Forbidden`) |
| **Viewer** (`Viewer`) | Pembaca dokumen saja | Ya | Tidak (`403 Forbidden`) | Tidak (`403 Forbidden`) |

> **Aturan Strict Sequential (Keputusan Disetujui):**
> Penandatanganan pada dokumen yang memiliki workflow berjenjang **harus berurutan ketat**. User pada Step 3 tidak boleh menandatangani sebelum Step 1 dan Step 2 selesai, dan **AgriDocs Admin tidak dapat melakukan bypass** urutan. Jika ada approver berhalangan, Admin mengubah approver step yang belum selesai melalui fitur **Override Approval Per-File**.

---

## 5. Spesifikasi Fungsional Lengkap (Baseline + Tiket 28–32)

### 5.1 Autentikasi & Sinkronisasi Tanda Tangan (Existing Baseline)
- Login menggunakan `username` (NIK) atau `email` + `password` akun `syncro_erp` melalui `POST /agrisign/api/auth/login`.
- Token Sanctum dan profil user disimpan secara persisten di perangkat (`SharedPreferences`).
- Spesimen tanda tangan (`users.signature_path`) disinkronkan dua arah antara server (`GET/PUT /me/signature`) dan cache lokal (`saved_signature.png`) untuk *one-tap reuse*.

### 5.2 Eksplorasi Folder Google Drive & Kartu Dokumen Gabungan (Existing + Tiket 29, 31)
- Pengguna dapat menelusuri subfolder Google Drive dengan navigasi *breadcrumb* dan pencarian nama file.
- **Perilaku Folder Berkategori:**
  - Pasangan file sumber (`Kontrak.pdf`) dan file hasil TTD (`Kontrak_signed.pdf`) tetap berada di dalam **1 folder Google Drive yang sama**, tetapi pada API & UI **digabung menjadi 1 kartu dokumen logis** (`effectiveFileId = signed_drive_file_id ?? drive_file_id`).
  - Saat file sumber PDF baru masuk ke folder kategori, backend otomatis membuat record `DocumentWorkflow` dan menyalin `templateSteps` kategori (Step 1 = `current`, Step 2..N = `waiting`).
  - File `_signed.pdf` historis yang sudah ada sebelumnya tidak boleh otomatis dibuatkan workflow baru sebagai file sumber.
- **Tampilan Status & Progress pada Kartu File:**
  - Badge **`GILIRAN ANDA TTD (Step X/Y)`** bila `approval.isMyTurn == true`.
  - Badge **`Menunggu: <Nama User> (<Jabatan>) • Step X/Y`** bila menunggu user lain.
  - Badge **`Selesai TTD (Y/Y)`** bila seluruh tahap selesai (`completed`).
  - Ringkasan alur step: contoh `✓ Andi → ⏳ Budi (Saat Ini) → ○ Citra`.
  - Badge kecil **`Custom`** bila file menggunakan override (`isCustomApproval == true`).

### 5.3 Tab "Giliran Saya" & Filter Status (Tiket 29, 30, 31)
- Di bawah *search bar* pada `DocumentListScreen`, tersedia 2 tab utama:
  1. **`Folder Drive`**: penelusuran folder, banner info kategori aktif, serta *filter chips* (`Semua`, `Giliran Saya`, `Proses TTD`, `Selesai`).
  2. **`Giliran Saya (N)`**: daftar dokumen lintas seluruh folder kategori yang saat ini `status = 'current'` milik user yang login (`GET /my-tasks`), lengkap dengan nama kategori/folder asal.
- Mengetuk dokumen dari tab **`Giliran Saya`** langsung membuka `PdfSigningScreen` dengan `folderIdOverride` tanpa mengubah posisi folder aktif di tab *Folder Drive*.

### 5.4 PDF Viewer & Penempelan Tanda Tangan Berjenjang (Existing + Tiket 28, 29, 31)
- Saat membuka dokumen berkategori, backend `GET /files/{fileId}/download` secara default menyajikan PDF progres terbaru (`signed_drive_file_id ?? drive_file_id`), dengan opsi `?variant=source` atau `?variant=signed`.
- Jika `document.approval != null && !document.approval!.canSign`, tombol **`Sign`**, **`Change sign`**, dan **`Simpan Dokumen`** dinonaktifkan/disembunyikan (mode baca + tetap bisa *Export PDF*).
- Saat user pada giliran aktif menandatangani dan menekan **Simpan Dokumen**:
  1. Backend memvalidasi urutan step (`403` jika bukan gilirannya, `409` jika sudah `completed`).
  2. Backend mengunduh PDF basis (`signed_drive_file_id ?? drive_file_id`), menempelkan TTD PNG, lalu memanggil `upsertSignedPdf()` agar Step 1 membuat `<nama>_signed.pdf` dan Step 2..N mengganti/memperbarui `<nama>_signed.pdf` di folder yang sama.
  3. Backend menandai step saat ini `signed` (`signed_at`, `signed_by_user_id`), memajukan `current_step_order` ke step berikutnya (`in_progress`) atau menandai `completed`.
  4. UI me-refresh `documentListProvider` & `myPendingTasksProvider`, serta menampilkan dialog konfirmasi berisi nama penanda tangan berikutnya atau status selesai final.

### 5.5 Manajemen Config Approval Kategori & Tambah Folder (Tiket 28, 29, 32 — Flutter-First, Admin Only)
- Hanya user dengan `currentUser.isAdmin == true` yang melihat tombol **`Config Approval`** di AppBar `DocumentListScreen`.
- Pada layar **`ApprovalConfigScreen`**:
  - Menampilkan daftar seluruh kategori/tipe dokumen (mis. 4 tipe dokumen = 4 kartu config beserta folder Drive & urutan approver).
  - **Tambah / Edit Kategori:**
    - Input nama kategori (wajib) & deskripsi (opsional).
    - Pilihan mode folder Google Drive:
      1. **Buat Folder Baru di Google Drive** (`createNewFolder: true`) $\rightarrow$ membuat subfolder di root/parent Drive melalui API lalu mengikatnya ke kategori.
      2. **Gunakan Folder Existing** $\rightarrow$ memilih subfolder Drive yang sudah ada.
    - **Builder Urutan Approver:** pilih user aktif Syncro ERP (nama, NIK/username, jabatan), isi label step opsional, geser naik/turun urutan, atau hapus step.
  - Perubahan template kategori otomatis menyinkronkan workflow di folder terkait yang masih `pending` dan `is_custom_approval = false`.
  - **Hapus Kategori:** menghapus mapping config dari DB (`nullOnDelete` pada workflow) tanpa menghapus folder/file di Google Drive.

### 5.6 Override Approval Per-File (Tiket 29, 32 — Admin Only)
- Hanya user dengan `currentUser.isAdmin == true` yang melihat tombol **`Atur Approval`** pada kartu file & AppBar `PdfSigningScreen`.
- Membuka **`FileApprovalEditorSheet`**:
  - Step berstatus **`signed`** tampil **terkunci** (tidak bisa diubah/dihapus) untuk menjaga integritas audit tanda tangan.
  - Step **`current`** / **`waiting`** dapat diubah user-nya, ditambah, dihapus, atau digeser urutannya.
  - Simpan memanggil `PUT /files/{fileId}/workflow`, menandai `is_custom_approval = true`, dan memperbarui workflow file tersebut tanpa mengubah file lain maupun template kategori.

---

## 6. Desain Data & Kontrak API (Tiket 28–30)

### 6.1 Skema Database (`Modules/AgriSign`)
1. `agrisign_document_categories`: `id`, `name`, `description`, `drive_folder_id` (unique), `drive_folder_name`, `is_active`, `created_by` (FK `users`), `timestamps`.
2. `agrisign_approval_template_steps`: `id`, `category_id` (FK cascade), `step_order`, `user_id` (FK `users`), `step_label`, `timestamps`, unique `(category_id, step_order)`.
3. `agrisign_document_workflows`: `id`, `category_id` (nullable FK nullOnDelete), `drive_file_id` (unique), `drive_folder_id` (indexed), `file_name`, `signed_drive_file_id`, `signed_file_name`, `status` (`pending` | `in_progress` | `completed`), `current_step_order`, `is_custom_approval`, `completed_at`, `timestamps`.
4. `agrisign_document_approval_steps`: `id`, `workflow_id` (FK cascade), `step_order`, `user_id` (FK `users`), `step_label`, `status` (`waiting` | `current` | `signed`), `signed_at`, `signed_by_user_id` (FK `users`), `timestamps`, unique `(workflow_id, step_order)`.

### 6.2 Ringkasan Endpoint API (`/agrisign/api/*`, `/api/agrisign/*`, `/api/v1/agrisign/*`)

| Method | Endpoint | Akses | Fungsi |
| :--- | :--- | :--- | :--- |
| `POST` | `auth/login` | Publik | Login akun Syncro ERP & terbitkan token Sanctum |
| `GET` | `me`, `me/signature` | `auth:sanctum` | Profil user + role modul `agrisign` + spesimen TTD |
| `PUT` | `me/signature` | `auth:sanctum` | Simpan/perbarui spesimen TTD ke server |
| `GET` | `files` | Token opsional/Sanctum | Daftar folder & file (+ `category`, `approval` per file) |
| `GET` | `files/{fileId}/download` | Token opsional/Sanctum | Unduh PDF (`?variant=source\|signed`, default progres terbaru) |
| `POST` | `files/{fileId}/sign` | Wajib `auth:sanctum` untuk workflow | Tempel TTD berjenjang, upsert `_signed.pdf`, majukan step |
| `GET` | `my-tasks` | `auth:sanctum` | Daftar dokumen lintas folder dengan `status = 'current'` milik user login |
| `GET` | `files/{fileId}/workflow` | `auth:sanctum` | Detail workflow & timeline step satu dokumen |
| `GET` | `users` | `auth:sanctum` + `agrisign.role:Admin` | Daftar user aktif Syncro ERP untuk pilihan approver |
| `GET/POST` | `categories` | `auth:sanctum` + `agrisign.role:Admin` | Daftar & buat kategori + subfolder Drive baru/existing |
| `PUT/DELETE` | `categories/{category}` | `auth:sanctum` + `agrisign.role:Admin` | Ubah config/template kategori atau hapus kategori |
| `PUT` | `files/{fileId}/workflow` | `auth:sanctum` + `agrisign.role:Admin` | Override rantai approval untuk satu file tertentu |

---

## 7. Roadmap Implementasi Tiket 28–32

1. **[Tiket 28](file:///C:/laragon/www/MyAcrobat/.scratch/myacrobat-mvp/issues/28-agridocs-backend-schema-roles-and-drive-ops.md)**: Fondasi Backend & Drive (`Code.gs` `createFolder`/`replace`, migrasi 4 tabel + 4 Eloquent models, `AgriSignRoleMiddleware`, `GoogleDriveVaultService::createFolder` & `upsertSignedPdf`).
2. **[Tiket 29](file:///C:/laragon/www/MyAcrobat/.scratch/myacrobat-mvp/issues/29-agridocs-backend-workflow-and-api.md)**: Workflow Engine & API (`AgriSignWorkflowService`, update `AgriSignFileController`, `AgriSignCategoryController`, rute API + Feature Tests).
3. **[Tiket 30](file:///C:/laragon/www/MyAcrobat/.scratch/myacrobat-mvp/issues/30-agridocs-flutter-models-api-and-state.md)**: Flutter Data Layer (model `document_approval.dart`, perluasan model & `MyAcrobatApiClient`, Riverpod `documentFilterProvider`, `myPendingTasksProvider`, `categoriesProvider`, `selectableUsersProvider`).
4. **[Tiket 31](file:///C:/laragon/www/MyAcrobat/.scratch/myacrobat-mvp/issues/31-agridocs-flutter-approval-status-and-viewer-ux.md)**: Flutter Approval Status & Viewer UX (tab `Folder Drive` vs `Giliran Saya (N)`, filter status, kartu dokumen berstatus + progress step, panel approval & strict sequential lock di `PdfSigningScreen`).
5. **[Tiket 32](file:///C:/laragon/www/MyAcrobat/.scratch/myacrobat-mvp/issues/32-agridocs-flutter-admin-config-and-override-ui.md)**: Flutter Admin UI (`ApprovalConfigScreen`, `FileApprovalEditorSheet`, integrasi tombol eksklusif Admin + widget tests).

---

## 8. Kriteria Keberhasilan (Acceptance Criteria v2.0)

1. Hanya user dengan role modul `agrisign = 'Admin'` yang dapat membuat/mengubah/menghapus kategori, membuat folder kategori di Drive, dan mengubah approval per file (`403` pada non-Admin di API & tombol tersembunyi di UI).
2. Pembuatan kategori dengan opsi folder baru berhasil membuat subfolder di Google Drive dan otomatis menginisiasi workflow untuk setiap file PDF sumber yang masuk ke folder tersebut.
3. Pasangan `Dokumen.pdf` + `Dokumen_signed.pdf` tampil sebagai satu kartu pada folder kategori; penanda tangan berikutnya otomatis membuka PDF progres terbaru dan menimpa/memperbarui `_signed.pdf` di folder yang sama tanpa duplikasi `_signed_2`, `_signed_3`.
4. Penandatanganan berjenjang menegakkan urutan ketat (*strict sequential*) di backend dan UI; Admin pun ditolak jika belum gilirannya.
5. Tab **`Giliran Saya (N)`** menampilkan antrean TTD user login lintas folder kategori dan dapat langsung dibuka serta ditandatangani tanpa berpindah folder aktif.
6. Override per-file mempertahankan step yang sudah `signed` dalam kondisi terkunci dan hanya mengubah workflow file tersebut (`isCustomApproval = true`).
