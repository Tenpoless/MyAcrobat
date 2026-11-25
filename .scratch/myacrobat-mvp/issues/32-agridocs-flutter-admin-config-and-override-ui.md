# 32 — Flutter Admin UI/UX: Config Approval Kategori, Tambah Folder & Override Per-File

Status: ready-for-agent
Type: feature
Blocked by: 30, 31

Repo target:
- `C:\laragon\www\MyAcrobat\app`

## Latar Belakang

Hanya user dengan role **AgriDocs Admin** (`currentUser.isAdmin == true`) yang boleh mengatur Config Approval per kategori/tipe dokumen, menambahkan folder kategori baru ke Google Drive, dan menyesuaikan rantai approval pada satu file tertentu tanpa mengubah template kategori. Sesuai keputusan desain, seluruh UI manajemen ini dibuat di aplikasi Flutter terlebih dahulu.

## Ruang Lingkup & Spesifikasi

### 1. Layar Master Config Approval & Tambah Folder (`app/lib/src/features/approval/approval_config_screen.dart`)
- **Akses Eksklusif AgriDocs Admin**:
  - Halaman hanya dibuka jika `authState.user?.isAdmin == true`; jika non-admin entah bagaimana membuka layar ini, tampilkan pesan akses ditolak (`Hanya AgriDocs Admin...`).
- **Daftar Kategori / Tipe Dokumen**:
  - Menampilkan semua kategori yang sudah ada (mis. 4 tipe dokumen = 4 kartu config), lengkap dengan nama folder Google Drive terkait dan ringkasan urutan penanda tangan (Step 1, Step 2, dst.).
  - Mendukung edit dan hapus kategori (dengan dialog konfirmasi hapus kategori; menjelaskan bahwa file di Google Drive tidak dihapus).
- **Form Tambah / Edit Kategori & Penambahan Folder**:
  - Field **Nama Kategori / Tipe Dokumen** (wajib) dan **Deskripsi** (opsional).
  - Pilihan **Mode Folder Google Drive**:
    1. **Buat Folder Baru di Google Drive**: input nama subfolder baru (default mengikuti nama kategori) yang otomatis dibuat saat simpan melalui API `createNewFolder: true` (di root folder AgriDocs atau subfolder parent yang dipilih).
    2. **Gunakan Folder Existing**: dropdown daftar subfolder root yang tersedia di Google Drive.
  - **Builder Urutan Approver Berjenjang**:
    - Tambah step: pilih user aktif Syncro ERP dari searchable modal/picker (menampilkan `name`, `username`/NIK, dan `position`), serta input opsional `stepLabel` (mis. *"Diperiksa"*, *"Disetujui"*).
    - Reorder step (tombol geser naik/turun) dan hapus step.
    - Validasi minimal 1 step atau konfirmasi sebelum simpan.

### 2. Bottom Sheet Override Approval Per-File (`app/lib/src/features/approval/file_approval_editor_sheet.dart`)
- Khusus **AgriDocs Admin**: memungkinkan penyesuaian rantai approval pada **1 file tertentu** tanpa memengaruhi file lain maupun template folder kategori.
- Menampilkan daftar step file tersebut:
  - Step dengan status `signed` ditampilkan sebagai **terkunci** (dengan tanda centang & waktu TTD) dan tidak dapat diubah/dihapus demi integritas histori tanda tangan.
  - Step yang belum selesai (`current` / `waiting`) dapat diubah user-nya, ditambah step baru, dihapus, atau digeser urutannya.
- Saat disimpan, memanggil `PUT /api/files/{fileId}/workflow`, menandai file memiliki custom approval (`isCustomApproval = true`), lalu me-refresh `documentListProvider` dan `myPendingTasksProvider`.

### 3. Integrasi Tombol Admin di `DocumentListScreen` & `PdfSigningScreen`
- Pada `DocumentListScreen`:
  - Di AppBar, tambahkan tombol **"Config Approval"** (`Icons.admin_panel_settings_outlined` / menu Pengaturan Approval) **HANYA jika `currentUser?.isAdmin == true`**. (Non-admin seperti `Signer` & `Viewer` tidak melihat tombol sama sekali).
  - Pada setiap kartu file PDF yang memiliki workflow (atau berada di folder aktif), tampilkan tombol/aksi kecil **"Atur Approval"** **HANYA jika `currentUser?.isAdmin == true`**, serta badge kecil `Custom` bila `approval.isCustomApproval == true`.
  - Setelah keluar dari `ApprovalConfigScreen` (karena kategori/folder baru ditambahkan), otomatis refresh daftar root/folder di `DocumentListScreen` sehingga folder baru langsung terlihat.
- Pada `PdfSigningScreen`:
  - Di AppBar viewer, tampilkan tombol **"Atur Approval"** **HANYA jika `currentUser?.isAdmin == true`** dan dokumen memiliki workflow/kategori, membuka `FileApprovalEditorSheet` dan langsung memperbarui state viewer setelah disimpan.

## Verifikasi

- Jalankan `flutter test --no-pub` dan `flutter analyze --no-pub lib test` di `C:\laragon\www\MyAcrobat\app`.
- Tambahkan widget tests di `app/test/approval_admin_ui_test.dart` (serta perluasan di `document_list_screen_test.dart`):
  - Role `signer` dan `viewer` tidak melihat tombol `Config Approval` maupun `Atur Approval`.
  - Role `admin` melihat tombol, dapat membuka `ApprovalConfigScreen`, membuat kategori baru dengan mode **Buat Folder Baru** + menyusun 2+ approver berurutan, dan memverifikasi payload API `createCategory` dipanggil dengan benar.
  - Role `admin` dapat membuka `FileApprovalEditorSheet` pada satu file, memastikan step yang sudah `signed` terkunci, mengubah step yang tersisa, dan memverifikasi `updateFileWorkflow` dipanggil.
