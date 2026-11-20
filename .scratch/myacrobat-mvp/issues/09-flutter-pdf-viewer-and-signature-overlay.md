# 09 — Halaman PDF Viewer Interaktif & Draggable/Resizable Signature Overlay

Status: resolved
Type: task
Blocked by: 07, 08

## Tujuan & Ruang Lingkup

Membangun halaman **PDF Viewer & Penempatan Tanda Tangan** (`app/lib/src/features/viewer/pdf_signing_screen.dart`) tempat pengguna membaca halaman PDF, menempelkan satu atau beberapa tanda tangan di atas halaman aktif, menggeser (*drag*) posisi tanda tangan, mengubah ukurannya (*resize* proporsional), dan menghasilkan koordinat rasio ternormalisasi (`pageIndex`, `xRatio`, `yRatio`, `widthRatio`, `heightRatio` dalam rentang `0.0–1.0`).

> **Batasan Tiket:** Tiket ini fokus pada tampilan halaman PDF, interaksi *drag & resize* overlay tanda tangan, dukungan multi-tanda tangan lintas halaman, dan konversi koordinat layar ke rasio halaman `0.0–1.0`. Proses pengiriman ke server untuk disimpan ke Mega.nz diselesaikan di Tiket 10.

## Detail Pekerjaan

1. **Controller Penempatan & Normalisasi Koordinat (`app/lib/src/features/viewer/signature_placement_controller.dart`):**
   - Menyimpan daftar `SignaturePlacement` aktif dalam sesi dokumen saat ini (setiap item memiliki `id`, `pageIndex`, `xRatio`, `yRatio`, `widthRatio`, `heightRatio`).
   - Saat pengguna menekan **"Bubuhkan Tanda Tangan"** pada halaman `currentPageIndex`:
     - Memanggil `resolveSignatureForPlacement()` (Tiket 08): jika belum ada TTD tersimpan akan membuka Signature Pad & auto-save; jika sudah ada langsung menempelkan overlay tanda tangan di tengah halaman aktif (`xRatio: 0.35, yRatio: 0.45, widthRatio: 0.30, heightRatio: 0.10`).
   - Fungsi murni `applyDragDelta` & `applyResizeDelta`:
     - Mengubah posisi pixel `(dx, dy)` di dalam kontainer halaman PDF berukuran `(pageRenderWidth, pageRenderHeight)` menjadi pembaruan `xRatio`, `yRatio`, `widthRatio`, `heightRatio`.
     - Melakukan *clamping* agar tanda tangan tidak keluar dari batas halaman PDF (`0.0 <= xRatio <= 1.0 - widthRatio` dan `0.0 <= yRatio <= 1.0 - heightRatio`).
   - Mendukung penghapusan satu item overlay tanda tangan (tombol `×` pada pojok kotak tanda tangan) sebelum dokumen disimpan.
2. **Komponen UI `DraggableSignatureOverlay` & `PdfSigningScreen`:**
   - Menampilkan halaman PDF serta indikator halaman aktif (`Halaman X dari Y` + navigasi halaman).
   - Menampilkan *floating resizable overlay* untuk setiap `SignaturePlacement` pada halaman terkait dengan bingkai putus-putus, *resize handle* di sudut kanan-bawah, dan tombol hapus (`×`) di sudut kanan-atas.
   - **Toolbar Bawah:**
     - Tombol utama **"Bubuhkan Tanda Tangan"** (memakai *One-Tap Reuse* jika sudah ada *Saved Signature*).
     - Tombol sekunder **"Ganti TTD"** (tampil bila sudah ada *Saved Signature*, memicu `forceRedraw: true` di Tiket 08).

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/signature_overlay_and_coordinates_test.dart`
- **Skenario Test (Red → Green):**
  1. Menambahkan tanda tangan pada halaman `0` membuat item `SignaturePlacement` dengan rasio default yang valid di dalam `[0.0, 1.0]`.
  2. Menggeser overlay sebesar `(+60px, +80px)` di atas kontainer halaman berukuran `300px x 400px` meningkatkan `xRatio` sebesar `+0.20` dan `yRatio` sebesar `+0.20`.
  3. Menggeser overlay melewati tepi halaman otomatis ter-*clamp* sehingga `xRatio + widthRatio <= 1.0` dan `yRatio + heightRatio <= 1.0`.
  4. Mengubah ukuran (*resize*) melalui handle sudut memperbarui `widthRatio` dan `heightRatio` secara proporsional dengan batas ukuran minimum aman.
  5. Pengguna dapat menambahkan tanda tangan pada halaman `0` dan halaman `1` dalam satu sesi, serta menghapus salah satu overlay dengan tombol `×`.

## Acceptance Criteria

- [x] Pengguna dapat menempelkan tanda tangan pada halaman PDF aktif (1 klik jika sudah punya *Saved Signature*).
- [x] Overlay tanda tangan dapat digeser (*drag*), diubah ukurannya (*resize*), atau dihapus sebelum disimpan.
- [x] Koordinat posisi dan ukuran tersimpan sebagai rasio ternormalisasi (`0.0–1.0`) yang akurat di semua ukuran layar.
- [x] Seluruh unit & widget test di `app/test/signature_overlay_and_coordinates_test.dart` lulus.

## Comments

- **2026-11-20**: Diselesaikan dengan TDD (`app/test/signature_overlay_and_coordinates_test.dart` — 5 skenario lulus, total 17 test lulus). Implementasi di `app/lib/src/features/viewer/signature_placement_controller.dart`, `app/lib/src/features/viewer/pdf_signing_screen.dart`, dan navigasi dari `app/lib/src/features/files/document_list_screen.dart`.
