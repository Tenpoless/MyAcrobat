# 31 — Flutter UI/UX: Daftar Dokumen Berstatus Approval, Tab Giliran Saya & Viewer Berjenjang

Status: ready-for-agent
Type: feature
Blocked by: 30

Repo target:
- `C:\laragon\www\MyAcrobat\app`

## Latar Belakang

Agar user **tidak perlu membuka file atau folder satu per satu** untuk mencari tahu apakah sudah gilirannya menandatangani, serta agar penanda tangan berikutnya **tidak perlu mengirim ulang file secara manual**, UI daftar dokumen dan viewer PDF perlu menampilkan status posisi approval secara eksplisit dan menegakkan urutan tanda tangan.

## Ruang Lingkup & Spesifikasi

### 1. Daftar Dokumen & Tab Giliran Saya (`app/lib/src/features/files/document_list_screen.dart`)
- **Dua Tab Utama di bawah Search Bar**:
  1. **`Folder Drive`**: breadcrumb + daftar folder + daftar dokumen di folder aktif.
  2. **`Giliran Saya (N)`**: menampilkan seluruh dokumen lintas folder kategori yang saat ini `status == 'current'` milik user yang login (menggunakan `myPendingTasksProvider`), lengkap dengan label nama kategori/folder asal dokumen.
- **Filter Chips Status di Folder Drive**:
  - `Semua`, `Giliran Saya`, `Proses TTD`, `Selesai` (muncul ketika folder memiliki dokumen ber-workflow atau selalu tersedia sebagai filter cepat).
- **Banner Kategori Folder**:
  - Saat berada di dalam folder yang terdaftar ke suatu Kategori Dokumen, tampilkan strip informasi ringkas (mis. `"Kategori: Kontrak Kerja • Approval Berjenjang Aktif"`).
- **Desain Kartu File PDF dengan Status Approval**:
  - Badge utama yang kontras dan langsung terbaca:
    - **`GILIRAN ANDA TTD (Step X/Y)`** (highlight aksen merah/emerald) bila `approval.isMyTurn == true`.
    - **`Menunggu: <Nama User> (<Jabatan>) • Step X/Y`** (badge amber) bila menunggu user lain.
    - **`Selesai TTD (Y/Y)`** (badge hijau) bila `approval.isCompleted`.
    - Tetap dukung badge `SIGNED` / `Sudah Ada Versi _signed` untuk folder tanpa kategori (*backward compatible*).
  - **Ringkasan Alur Penanda Tangan (Progress Step)**:
    - Tampilkan chip/baris ringkas urutan user tepat pada kartu (atau bagian expand/detail ringkas): mis. `✓ Andi  →  ⏳ Budi (Saat Ini)  →  ○ Citra`.
  - Saat kartu diklik untuk dokumen berkategori: langsung membuka `PdfSigningScreen` dengan `folderIdOverride` (otomatis mengunduh PDF progres terbaru dari backend), serta opsi menu/ikon cepat untuk Export/Unduh versi `_signed.pdf` jika sudah ada.

### 2. Viewer & Signing Flow (`app/lib/src/features/viewer/pdf_signing_screen.dart`)
- Tambah parameter opsional `String? folderIdOverride` pada `PdfSigningScreen` agar dokumen yang dibuka dari tab **`Giliran Saya`** (berasal dari folder kategori mana pun) meneruskan `folderId` yang tepat saat `downloadPdfBytes` dan `signDocument`.
- **Panel Info Posisi Approval**:
  - Tampilkan banner informatif di atas/bawah viewer yang menjelaskan status file saat ini (mis. `"Giliran Anda: Step 2 dari 3"`, atau `"Sedang menunggu TTD dari Ir. Ahmad (Step 2/3)"`, atau `"Dokumen telah selesai ditandatangani (3/3)"`).
  - Sediakan tombol/ikon detail timeline step agar user bisa melihat daftar lengkap siapa sudah TTD beserta timestamp `signedAt` dan siapa berikutnya.
- **Penegakan Strict Sequential di UI**:
  - Jika `document.approval != null && !document.approval!.canSign`:
    - Sembunyikan/nonaktifkan tombol `Sign`, `Change sign`, dan `Simpan Dokumen` (tampilkan banner mode baca / menunggu giliran user lain; user tetap bisa membaca PDF dan mengekspor PDF).
    - Catatan: jika `document.approval == null` (folder non-kategori) atau `document.approval!.status == 'unconfigured'`, perilaku signing cepat tetap mengikuti aturan role `viewer` vs `signer/admin` seperti sebelumnya.
- **Dialog Sukses Setelah Simpan**:
  - Setelah `signDocument` berhasil: refresh `documentListProvider` dan `myPendingTasksProvider`.
  - Jika response mengembalikan `approval` dengan step berikutnya, tampilkan pesan status lanjutan: mis. *"Tanda tangan tersimpan. Dokumen sekarang menunggu TTD berikutnya: [Nama User] (Step X/Y)."*; jika selesai semua step: *"Seluruh tahap TTD selesai. Dokumen final _signed.pdf tersimpan di folder yang sama."*

## Verifikasi

- Jalankan `flutter test --no-pub` dan `flutter analyze --no-pub lib test` di `C:\laragon\www\MyAcrobat\app`.
- Tambahkan widget tests di `app/test/document_list_screen_test.dart` & `app/test/save_signed_document_flow_test.dart`:
  - Rendering kartu dengan status `GILIRAN ANDA TTD`, `Menunggu: [Nama User]`, dan `Selesai TTD` beserta ringkasan urutan step.
  - Perpindahan ke tab **Giliran Saya** menampilkan dokumen lintas folder dengan label kategori, dan tap dokumen mengirim `folderIdOverride` yang benar ke viewer.
  - `PdfSigningScreen` mengunci tombol `Sign` & `Simpan Dokumen` saat `canSign == false` (menunggu user lain atau sudah selesai), dan menampilkan info status penanda tangan berikutnya pada dialog sukses simpan.
