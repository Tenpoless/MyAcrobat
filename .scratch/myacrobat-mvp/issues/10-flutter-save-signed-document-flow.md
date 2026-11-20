# 10 — Alur Simpan Dokumen (`_signed.pdf`) & Sinkronisasi Kembali ke Mega.nz

Status: resolved
Type: task
Blocked by: 05, 09

## Tujuan & Ruang Lingkup

Menyelesaikan alur akhir MVP sesuai PRD Bagian 3.3: menghubungkan tombol **"Simpan Dokumen"** pada `PdfSigningScreen` ke endpoint `POST /api/files/:fileId/sign`, menampilkan progres penyimpanan/pengunggahan ke Mega.nz, memberi konfirmasi berhasil beserta nama file baru `<nama_asli>_signed.pdf`, dan memperbarui daftar dokumen Mega.nz sehingga file `_signed.pdf` baru langsung muncul.

> **Batasan Tiket:** Tiket ini menyelesaikan integrasi aksi simpan dari layar penandatanganan Flutter ke backend hingga pembaruan daftar file Mega.nz.

## Detail Pekerjaan

1. **Aksi Tombol `"Simpan Dokumen"` di `PdfSigningScreen`:**
   - Tombol **"Simpan Dokumen"** aktif apabila terdapat minimal 1 `SignaturePlacement` pada dokumen dan `SavedSignature` tersedia.
   - Saat ditekan:
     1. Mengubah state ke `isSaving = true` (menampilkan indikator loading `"Menyimpan & Mengunggah <nama>_signed.pdf ke Mega.nz..."` dan menonaktifkan interaksi ganda).
     2. Memanggil `apiClient.signDocument(fileId: sourceFile.fileId, signaturePngBytes: signatureBytes, placements: placements)`.
     3. Memicu refresh pada `documentListProvider` agar daftar file Mega.nz terbarui.
     4. Menampilkan dialog/sheet sukses yang memuat nama file baru (`result.signedFile.name`, mis. `Surat_Perjanjian_signed.pdf`) dengan 2 tombol pilihan:
        - **"Buka File `_signed.pdf`"** (langsung membuka dokumen hasil tanda tangan di viewer untuk verifikasi visual).
        - **"Kembali ke Daftar Dokumen"**.
   - Jika terjadi kegagalan jaringan/server: menampilkan `SnackBar` / dialog error tanpa menghilangkan posisi tanda tangan yang sudah diatur pengguna di layar sehingga pengguna cukup menekan **"Coba Simpan Lagi"**.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/save_signed_document_flow_test.dart`
- **Skenario Test (Red → Green):**
  1. Tombol `"Simpan Dokumen"` nonaktif sebelum ada tanda tangan yang ditempelkan di halaman PDF, dan otomatis aktif begitu 1 tanda tangan ditempelkan.
  2. Saat `"Simpan Dokumen"` ditekan, aplikasi mengirim payload `signaturePngBytes` dan `placements` ke `MyAcrobatApiClient.signDocument()`, menampilkan konfirmasi sukses berisi nama file baru `Kontrak_signed.pdf`, dan me-refresh daftar dokumen.
  3. Saat server mengembalikan error, pesan gagal tampil tetapi overlay tanda tangan pengguna di halaman PDF tidak hilang (bisa langsung dicoba simpan ulang).

## Acceptance Criteria

- [x] Menekan `"Simpan Dokumen"` mengirimkan koordinat rasio dan PNG tanda tangan ke backend dan menghasilkan file `<nama_asli>_signed.pdf` di Mega.nz.
- [x] Dialog konfirmasi sukses menampilkan nama file `_signed.pdf` yang baru dibuat beserta opsi langsung membukanya atau kembali ke daftar dokumen.
- [x] Jika gagal simpan karena jaringan, posisi tanda tangan di layar tidak hilang.
- [x] Seluruh widget/integration test di `app/test/save_signed_document_flow_test.dart` lulus.

## Comments

- **2026-11-20**: Diselesaikan dengan TDD (`app/test/save_signed_document_flow_test.dart` — 3 skenario lulus, total 20 test lulus). Implementasi di `app/lib/src/features/viewer/pdf_signing_screen.dart`.
