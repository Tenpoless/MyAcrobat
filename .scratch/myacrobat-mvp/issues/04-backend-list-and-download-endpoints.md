# 04 — Endpoint `GET /api/files` & `GET /api/files/:fileId/download`

Status: resolved
Type: task
Blocked by: 02

## Tujuan & Ruang Lingkup

Menambahkan dua endpoint pembacaan dokumen ke aplikasi Fastify sesuai kontrak PRD Bagian 5:
1. `GET /api/files` — Mengambil daftar dokumen PDF dari **Cloud Vault** Mega.nz.
2. `GET /api/files/:fileId/download` — Mengunduh binary PDF berdasarkan `fileId` untuk ditampilkan di PDF Viewer Flutter.

> **Batasan Tiket:** Tiket ini hanya mencakup endpoint baca (`GET`). Endpoint penandatanganan (`POST /api/files/:fileId/sign`) dikerjakan terpisah di Tiket 05.

## Detail Pekerjaan

1. **Dependency Injection pada `buildApp({ vault })` (`backend/src/app.ts`):**
   - `buildApp` menerima instance `CloudVault` sehingga pada saat runtime memakai `MegaCloudVaultAdapter`, sedangkan pada saat testing dapat disuntikkan fake/in-memory `CloudVault` adapter di seam `CloudVault`.
2. **Route `GET /api/files`:**
   - Memanggil `vault.listPdfFiles()`.
   - Mendukung query opsional `?search=<keyword>` (memfilter nama file secara case-insensitive jika dikirim, atau mengembalikan semua file PDF jika tidak dikirim).
   - Mengembalikan HTTP `200` dengan format JSON:
     ```json
     {
       "files": [
         {
           "fileId": "node-123",
           "name": "Surat_Perjanjian.pdf",
           "size": 245120,
           "updatedAt": "2026-11-20T02:30:00.000Z",
           "isSigned": false
         }
       ]
     }
     ```
3. **Route `GET /api/files/:fileId/download`:**
   - Memanggil `vault.downloadPdf(req.params.fileId)`.
   - Mengatur response header:
     - `Content-Type: application/pdf`
     - `Content-Disposition: inline; filename="<name>"`
     - `Content-Length: <bytes.byteLength>`
   - Mengirimkan binary `Buffer.from(bytes)`.
   - Jika `VaultFileNotFoundError` dilempar, kembalikan HTTP `404` dengan `{ error: 'File PDF tidak ditemukan di Mega.nz' }`.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/files-read-routes.test.ts`
- **Skenario Test (Red → Green):**
  1. `GET /api/files` mengembalikan HTTP `200` beserta daftar file PDF (`fileId`, `name`, `size`, `updatedAt`, `isSigned`).
  2. `GET /api/files?search=perjanjian` menyaring daftar file sesuai kata kunci nama file.
  3. `GET /api/files/:fileId/download` mengembalikan HTTP `200`, header `content-type: application/pdf`, dan isi byte PDF yang identik dengan yang ada di `CloudVault`.
  4. `GET /api/files/unknown-id/download` mengembalikan HTTP `404` JSON error.

## Acceptance Criteria

- [x] `GET /api/files` mengembalikan daftar PDF sesuai skema PRD.
- [x] `GET /api/files/:fileId/download` mengalirkan binary PDF dengan header `application/pdf`.
- [x] Penanganan HTTP `404` saat `fileId` tidak ditemukan berjalan rapi.
- [x] Seluruh integration test di `backend/tests/files-read-routes.test.ts` lulus.

## Comments

- Selesai diimplementasikan dengan TDD (`4 passed` pada `files-read-routes.test.ts`).
