# 07 — Halaman Daftar Dokumen PDF Mega.nz (Pencarian & Indikator `_signed`)

Status: resolved
Type: task
Blocked by: 04, 06

## Tujuan & Ruang Lingkup

Membangun halaman utama (**Daftar Dokumen PDF**) di aplikasi Flutter (`app/lib/src/features/files/document_list_screen.dart`) yang menampilkan daftar file PDF dari akun Mega.nz terpusat, lengkap dengan kolom pencarian nama file, aksi *refresh*, indikator status file yang sudah memiliki versi `_signed`, dan navigasi saat item dokumen diklik.

> **Batasan Tiket:** Tiket ini hanya mengerjakan layar eksplorasi daftar dokumen PDF dari Mega.nz. Layar PDF Viewer dan pembubuhan tanda tangan dikerjakan di Tiket 09.

## Detail Pekerjaan

1. **State Provider (`app/lib/src/features/files/document_list_provider.dart`):**
   - Mengambil daftar `List<VaultPdfFile>` melalui `MyAcrobatApiClient.fetchFiles()`.
   - Menyediakan state pencarian nama file (`searchQueryProvider`) untuk memfilter daftar PDF secara *real-time* di sisi klien.
   - Mendukung method `refresh()` untuk memuat ulang daftar dokumen dari Mega.nz (dipakai saat *pull-to-refresh* atau selesai menyimpan dokumen `_signed.pdf`).
2. **Komponen UI `DocumentListScreen` (`app/lib/src/features/files/document_list_screen.dart`):**
   - **AppBar:** Judul `MyAcrobat — Dokumen Mega.nz` + tombol ikon Refresh (`Icons.refresh`).
   - **Search Bar:** `TextField` pencarian dengan placeholder `"Cari nama dokumen PDF..."` dan tombol *clear* saat teks tidak kosong.
   - **Daftar File PDF:**
     - Menampilkan nama file, ukuran file (`formattedSize`), dan tanggal perubahan terakhir.
     - Menampilkan **Badge Status**:
       - Jika `file.isSigned == true` (file berakhiran `_signed.pdf`): tampilkan badge hijau `SIGNED`.
       - Jika `file.isSigned == false` tetapi di dalam daftar sudah terdapat file pasangan `<nama>_signed.pdf`: tampilkan badge informasi `Sudah Ada Versi _signed`.
   - **Empty & Error States:**
     - Tampilan saat belum ada file PDF atau hasil pencarian kosong.
     - Tampilan saat koneksi ke server gagal beserta tombol **"Coba Lagi"**.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/document_list_screen_test.dart`
- **Skenario Widget Test (Red → Green):**
  1. Saat daftar dokumen berhasil dimuat (`Surat_Perjanjian.pdf` dan `Surat_Perjanjian_signed.pdf`), keduanya tampil di layar beserta badge `SIGNED` pada file kedua dan indikator bahwa file pertama sudah memiliki versi `_signed`.
  2. Saat pengguna mengetik di kotak pencarian, daftar dokumen langsung terfilter sesuai kata kunci.
  3. Saat terjadi error jaringan, layar menampilkan pesan error dan tombol `"Coba Lagi"` yang memicu pemanggilan ulang data.

## Acceptance Criteria

- [x] `DocumentListScreen` menampilkan daftar dokumen PDF dari `MyAcrobatApiClient`.
- [x] Pencarian nama file, tombol refresh, badge `SIGNED`, dan indikator pasangan `_signed` berfungsi sesuai spesifikasi PRD 3.1.
- [x] Seluruh widget test di `app/test/document_list_screen_test.dart` lulus.

## Comments

- **2026-11-20:** `DocumentListNotifier` (`documentListProvider`, `searchQueryProvider`, `filteredDocumentsProvider`, `hasSignedCounterpart`) dan `DocumentListScreen` selesai diimplementasikan dengan standar `antislop` (`DURING` mode) dan diverifikasi via TDD (`3 passed` di `app/test/document_list_screen_test.dart`, total `8 passed`).
