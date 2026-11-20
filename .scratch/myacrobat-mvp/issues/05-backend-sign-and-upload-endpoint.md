# 05 — Endpoint `POST /api/files/:fileId/sign` (Embed TTD & Upload `_signed.pdf`)

Status: resolved
Type: task
Blocked by: 02, 03

## Tujuan & Ruang Lingkup

Mengimplementasikan endpoint utama `POST /api/files/:fileId/sign` di Fastify yang mengorkestrasi alur penuh di sisi server:
1. Mengunduh **Source Document** dari **Cloud Vault** Mega.nz berdasarkan `:fileId`.
2. Menempelkan (*embed & flatten*) gambar tanda tangan PNG ke halaman PDF pada koordinat `placements` menggunakan `embedSignatureIntoPdf`.
3. Mengunggah hasil PDF sebagai file baru `<nama_asli>_signed.pdf` (**Signed Document**) ke folder yang sama di Mega.nz tanpa mengubah file asli.

> **Batasan Tiket:** Tiket ini menyatukan `CloudVault` (Tiket 02) dan `PdfSignatureEmbedder` (Tiket 03) ke dalam endpoint HTTP `POST /api/files/:fileId/sign`.

## Detail Pekerjaan

1. **Kontrak Request `POST /api/files/:fileId/sign`:**
   ```json
   {
     "signatureImageBase64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...",
     "placements": [
       {
         "pageIndex": 0,
         "xRatio": 0.62,
         "yRatio": 0.78,
         "widthRatio": 0.22,
         "heightRatio": 0.08
       }
     ]
   }
   ```
2. **Validasi Request & Error Handling:**
   - Jika `signatureImageBase64` kosong atau bukan PNG valid $\rightarrow$ HTTP `400` (`{ error: 'signatureImageBase64 wajib diisi dengan PNG valid' }`).
   - Jika `placements` bukan array atau kosong $\rightarrow$ HTTP `400` (`{ error: 'Minimal satu posisi tanda tangan (placements) wajib dikirim' }`).
   - Jika `InvalidSignaturePlacementError` terjadi (mis. `pageIndex` di luar jumlah halaman PDF atau rasio di luar `0.0–1.0`) $\rightarrow$ HTTP `400` dengan pesan error detail.
   - Jika `:fileId` tidak ditemukan di Mega.nz $\rightarrow$ HTTP `404`.
3. **Kontrak Response Sukses (HTTP `201 Created`):**
   ```json
   {
     "message": "Dokumen berhasil ditandatangani dan disimpan ke Mega.nz",
     "sourceFileId": "node-123",
     "signedFile": {
       "fileId": "node-456",
       "name": "Surat_Perjanjian_signed.pdf",
       "size": 258900,
       "updatedAt": "2026-11-20T03:10:00.000Z",
       "isSigned": true
     }
   }
   ```

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/file-sign-route.test.ts`
- **Skenario Test (Red → Green):**
  1. Mengirim `POST /api/files/:fileId/sign` dengan PDF asli di in-memory vault, PNG transparan Base64 valid, dan 1 placement rasio $\rightarrow$ mengembalikan HTTP `201`, membuat file baru `*_signed.pdf` di vault dengan `isSigned: true`, sementara file asli tetap ada dan byte-nya tidak berubah.
  2. Mengirim `placements: []` atau tanpa `signatureImageBase64` $\rightarrow$ mengembalikan HTTP `400`.
  3. Mengirim `pageIndex: 99` pada PDF 1 halaman $\rightarrow$ mengembalikan HTTP `400`.
  4. Mengirim `:fileId` yang tidak ada $\rightarrow$ mengembalikan HTTP `404`.

## Acceptance Criteria

- [x] `POST /api/files/:fileId/sign` memproses unduh PDF, embed PNG tanda tangan, dan unggah file baru `<nama>_signed.pdf` ke Cloud Vault.
- [x] File asli di Cloud Vault tetap utuh 100% (*non-destructive*).
- [x] Validasi input menghasilkan HTTP `400` / `404` yang konsisten.
- [x] Seluruh test di `backend/tests/file-sign-route.test.ts` lulus.

## Comments

- Selesai diimplementasikan dengan TDD (`4 passed` pada `file-sign-route.test.ts`).
