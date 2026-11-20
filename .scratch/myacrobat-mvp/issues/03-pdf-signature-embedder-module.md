# 03 — Modul `PdfSignatureEmbedder` (`pdf-lib`) & Konversi Koordinat Rasio (`0.0–1.0`)

Status: resolved
Type: task
Blocked by: 01

## Tujuan & Ruang Lingkup

Membangun *deep module* `PdfSignatureEmbedder` di `backend/src/pdf/pdf-signature-embedder.ts` menggunakan `pdf-lib` untuk menempelkan (*embed & flatten*) gambar PNG transparan tanda tangan ke dalam satu atau beberapa halaman PDF berdasarkan rasio koordinat ternormalisasi (`xRatio`, `yRatio`, `widthRatio`, `heightRatio`).

> **Batasan Tiket:** Tiket ini fokus murni pada manipulasi binary PDF dan matematika transformasi koordinat dari sistem layar Flutter (*top-left origin*) ke sistem halaman PDF `pdf-lib` (*bottom-left origin*).

## Detail Pekerjaan

1. **Kontrak Interface (`backend/src/pdf/pdf-signature-embedder.ts`):**
   ```ts
   export interface SignaturePlacementInput {
     pageIndex: number;   // 0-based index halaman PDF
     xRatio: number;      // 0.0 - 1.0 (jarak kiri tanda tangan dari tepi kiri halaman)
     yRatio: number;      // 0.0 - 1.0 (jarak atas tanda tangan dari tepi atas halaman)
     widthRatio: number;  // 0.0 - 1.0 (proporsi lebar tanda tangan terhadap lebar halaman)
     heightRatio: number; // 0.0 - 1.0 (proporsi tinggi tanda tangan terhadap tinggi halaman)
   }

   export async function embedSignatureIntoPdf(params: {
     pdfBytes: Uint8Array;
     signaturePngBase64OrBytes: string | Uint8Array;
     placements: SignaturePlacementInput[];
   }): Promise<Uint8Array>;
   ```
2. **Rumus Transformasi Koordinat (Layar Top-Left $\rightarrow$ PDF Bottom-Left):**
   - Di Flutter (UI), titik `(0, 0)` berada di **kiri-atas** halaman, sedangkan di `pdf-lib` (`page.drawImage`), titik `(0, 0)` berada di **kiri-bawah** halaman.
   - Untuk halaman dengan dimensi `{ width: pageWidth, height: pageHeight }`:
     - `drawWidth = widthRatio * pageWidth`
     - `drawHeight = heightRatio * pageHeight`
     - `drawX = xRatio * pageWidth`
     - `drawY = pageHeight - (yRatio * pageHeight) - drawHeight`
3. **Validasi & Keandalan:**
   - Mendukung input `signaturePngBase64OrBytes` baik berupa string data URL (`data:image/png;base64,...`), Base64 murni, maupun `Uint8Array`.
   - Memvalidasi `placements` tidak boleh kosong (`placements.length > 0`).
   - Memvalidasi setiap `pageIndex` berada dalam rentang `0 <= pageIndex < pages.length` (lempar `InvalidSignaturePlacementError` jika di luar rentang atau jika rasio `< 0` atau `> 1`).
   - Memanggil `pdfDoc.embedPng(...)` satu kali, lalu menggambar gambar tersebut pada setiap item di `placements` (mendukung multi-posisi / multi-halaman dalam satu kali proses).

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/pdf-signature-embedder.test.ts`
- **Skenario Test (Red → Green):**
  1. Membuat PDF 2 halaman berukuran `600 x 800` menggunakan `pdf-lib` di dalam test, lalu memanggil `embedSignatureIntoPdf()` dengan `xRatio: 0.5, yRatio: 0.75, widthRatio: 0.2, heightRatio: 0.1` pada `pageIndex: 0`.
  2. Memastikan fungsi mengembalikan `Uint8Array` PDF valid yang dapat dibuka kembali oleh `PDFDocument.load()`, jumlah halaman tetap 2, dan ukuran byte bertambah karena objek image PNG telah ter-embed.
  3. Memastikan kalkulasi `computePdfDrawBox({ pageWidth: 600, pageHeight: 800 }, { xRatio: 0.5, yRatio: 0.75, widthRatio: 0.2, heightRatio: 0.1 })` menghasilkan `{ x: 300, y: 120, width: 120, height: 80 }` secara eksak (`800 - 600 - 80 = 120`).
  4. Melempar `InvalidSignaturePlacementError` apabila `pageIndex` melebihi jumlah halaman PDF atau rasio bernilai negatif / `> 1`.

## Acceptance Criteria

- [x] `computePdfDrawBox()` mengonversi koordinat *top-left ratio* ke *bottom-left PDF points* dengan presisi.
- [x] `embedSignatureIntoPdf()` menempelkan PNG transparan pada 1 atau lebih halaman PDF dan menghasilkan binary PDF valid.
- [x] Validasi `pageIndex` dan rentang rasio `0.0–1.0` berfungsi dengan pesan error yang jelas.
- [x] Seluruh unit test di `backend/tests/pdf-signature-embedder.test.ts` lulus.

## Comments

- Selesai diimplementasikan dengan TDD (`3 passed` pada `pdf-signature-embedder.test.ts`).
