# 08 — Modul Auto-Save `SavedSignatureRepository` & Modal `SignaturePad` (One-Tap Reuse)

Status: resolved
Type: task
Blocked by: 06

## Tujuan & Ruang Lingkup

Mengimplementasikan fitur inti **Auto-Save Tanda Tangan Pertama & One-Tap Reuse** sesuai spesifikasi PRD Bagian 3.2:
1. Saat pengguna **pertama kali** menekan tombol **"Tanda Tangan"** (belum ada **Saved Signature**), aplikasi membuka modal **Signature Pad** untuk menggambar tanda tangan, lalu **otomatis menyimpan (*auto-save*)** gambar PNG transparan tersebut ke penyimpanan lokal perangkat begitu pengguna menekan **"Gunakan Tanda Tangan"**.
2. Saat pengguna menekan tombol **"Tanda Tangan"** untuk **kedua kalinya dan seterusnya** (baik di halaman lain maupun dokumen lain), aplikasi **tidak membuka Signature Pad lagi**, melainkan langsung mengembalikan **Saved Signature** tersebut agar langsung ditempel ke halaman PDF.
3. Menyediakan aksi sekunder **"Gambar Ulang / Ganti TTD"** yang membuka kembali modal **Signature Pad** dan menimpa **Saved Signature** lokal dengan gambar baru.

> **Batasan Tiket:** Tiket ini fokus penuh pada *repository* penyimpanan tanda tangan lokal, logika keputusan *First-Time Draw vs. One-Tap Reuse*, dan komponen modal `SignaturePadSheet`.

## Detail Pekerjaan

1. **Modul `SavedSignatureRepository` (`app/lib/src/features/signature/saved_signature_repository.dart`):**
   - Interface `SignatureStorage`:
     - `Future<Uint8List?> loadSavedSignature()`
     - `Future<void> saveSignature(Uint8List pngBytes)`
     - `Future<void> clearSavedSignature()`
     - `Future<bool> hasSavedSignature()`
   - Implementasi default menyimpan file binary PNG transparan di direktori dokumen aplikasi (`saved_signature.png` via `path_provider`) + implementasi in-memory/file sementara untuk pengujian.
2. **Modal `SignaturePadSheet` (`app/lib/src/features/signature/signature_pad_sheet.dart`):**
   - Kanvas gambar tanda tangan berlatar transparan dengan pilihan warna pena (**Hitam** / **Biru**) dan ketebalan goresan.
   - Tombol **"Bersihkan" (*Clear*)** untuk mengulang goresan di kanvas.
   - Tombol **"Gunakan Tanda Tangan"**:
     - Mengekspor goresan kanvas menjadi `Uint8List` PNG transparan.
     - Memanggil `repository.saveSignature(pngBytes)` (**Auto-Save**).
     - Menutup modal dan mengembalikan `pngBytes` ke pemanggil.
3. **Helper Orkestrasi `resolveSignatureForPlacement({required BuildContext context, required SavedSignatureRepository repo, bool forceRedraw = false})`:**
   - Jika `forceRedraw == false` dan `await repo.loadSavedSignature()` sudah ada $\rightarrow$ **langsung kembalikan `Uint8List` tanda tangan tersimpan tanpa menampilkan modal** (*One-Tap Reuse*).
   - Jika belum ada tanda tangan tersimpan atau `forceRedraw == true` $\rightarrow$ tampilkan `SignaturePadSheet`, auto-save hasilnya, lalu kembalikan `Uint8List` tersebut.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/saved_signature_and_pad_test.dart`
- **Skenario Test (Red → Green):**
  1. Ketika `SavedSignatureRepository` masih kosong, pemanggilan `resolveSignatureForPlacement` membuka modal `SignaturePadSheet`. Setelah tanda tangan disimpan, `repo.hasSavedSignature()` bernilai `true`.
  2. Pada pemanggilan kedua (`repo.hasSavedSignature() == true` dan `forceRedraw: false`), `resolveSignatureForPlacement` langsung mengembalikan byte PNG yang tersimpan **tanpa** membuka `SignaturePadSheet` di layar.
  3. Ketika pengguna memilih **"Gambar Ulang / Ganti TTD"** (`forceRedraw: true`), `SignaturePadSheet` terbuka kembali dan memperbarui `SavedSignatureRepository` dengan byte tanda tangan baru.

## Acceptance Criteria

- [x] Tanda tangan pertama otomatis tersimpan (*auto-save*) sebagai PNG transparan.
- [x] Aksi tanda tangan kedua dan seterusnya langsung memuat tanda tangan tersimpan tanpa meminta gambar ulang.
- [x] Aksi **"Gambar Ulang / Ganti TTD"** memungkinkan pengguna memperbarui tanda tangan tersimpan kapan saja.
- [x] Seluruh unit & widget test di `app/test/saved_signature_and_pad_test.dart` lulus.

## Comments

- **2026-11-20**: Diselesaikan dengan TDD (`app/test/saved_signature_and_pad_test.dart` — 4 skenario lulus, total 12 test lulus). Implementasi di `app/lib/src/features/signature/saved_signature_repository.dart` dan `app/lib/src/features/signature/signature_pad_sheet.dart`.
