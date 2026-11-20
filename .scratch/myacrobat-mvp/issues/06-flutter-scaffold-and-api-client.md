# 06 — Inisialisasi Proyek Flutter (`app/`) & Modul `MyAcrobatApiClient` (`dio`)

Status: resolved
Type: task
Blocked by: none

## Tujuan & Ruang Lingkup

Menyiapkan proyek aplikasi Flutter di direktori `app/` beserta konfigurasi dependencies utama (`flutter_riverpod`, `dio`, `pdfrx`, `signature`, `path_provider`, `shared_preferences`) dan membangun modul klien HTTP `MyAcrobatApiClient` beserta model data (`VaultPdfFile`, `SignaturePlacement`, `SignDocumentResponse`) yang sesuai dengan kontrak API Backend.

> **Batasan Tiket:** Tiket ini fokus pada inisialisasi struktur proyek Flutter, model domain Dart, dan klien API `MyAcrobatApiClient` beserta unit test-nya. Pembuatan halaman UI dikerjakan pada Tiket 07, 08, 09, dan 10.

## Detail Pekerjaan

1. **Inisialisasi Proyek Flutter (`app/`):**
   - `app/pubspec.yaml` dengan dependencies:
     - `flutter_riverpod` (state management)
     - `dio` (HTTP client)
     - `pdfrx` (atau `syncfusion_flutter_pdfviewer` untuk PDF rendering)
     - `signature` (kanvas tanda tangan PNG transparan)
     - `path_provider` & `shared_preferences` (penyimpanan lokal *Saved Signature*)
2. **Model Domain (`app/lib/src/models/`):**
   - `VaultPdfFile`: `fileId`, `name`, `size`, `updatedAt`, `isSigned`, serta getter helper `formattedSize` (mis. `240 KB` / `1.2 MB`).
   - `SignaturePlacement`: `pageIndex`, `xRatio`, `yRatio`, `widthRatio`, `heightRatio` dengan `toJson()` dan validasi rasio `0.0–1.0`.
   - `SignDocumentResult`: `message`, `sourceFileId`, `signedFile` (`VaultPdfFile`).
3. **Modul `MyAcrobatApiClient` (`app/lib/src/api/myacrobat_api_client.dart`):**
   - Menerima `Dio` instance dan `baseUrl` (default `http://localhost:3000` atau `http://10.0.2.2:3000` untuk emulator Android, dapat dikonfigurasi via `--dart-define=API_BASE_URL=...`).
   - Method:
     - `Future<List<VaultPdfFile>> fetchFiles({String? search})` $\rightarrow$ `GET /api/files`
     - `Future<Uint8Array / Uint8List> downloadPdfBytes(String fileId)` $\rightarrow$ `GET /api/files/:fileId/download`
     - `Future<SignDocumentResult> signDocument({required String fileId, required Uint8List signaturePngBytes, required List<SignaturePlacement> placements})` $\rightarrow$ mengonversi `signaturePngBytes` ke `data:image/png;base64,...` dan memanggil `POST /api/files/:fileId/sign`.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/api_client_and_models_test.dart`
- **Skenario Test (Red → Green):**
  1. Serialisasi/deserialisasi `VaultPdfFile.fromJson()` dan `SignaturePlacement.toJson()` sesuai dengan contoh payload di PRD Bagian 5.
  2. `MyAcrobatApiClient.fetchFiles()` mem-parsing JSON `{ "files": [...] }` menjadi `List<VaultPdfFile>`.
  3. `MyAcrobatApiClient.signDocument()` mengirim body JSON dengan `signatureImageBase64` berawalan `data:image/png;base64,` dan array `placements`, lalu mem-parsing response `201` menjadi `SignDocumentResult`.

## Acceptance Criteria

- [x] Proyek Flutter di `app/` terkonfigurasi dengan dependencies MVP dan lolos `flutter test`.
- [x] Model `VaultPdfFile`, `SignaturePlacement`, dan `SignDocumentResult` sesuai dengan kontrak PRD.
- [x] `MyAcrobatApiClient` memiliki unit test yang memverifikasi kontrak `fetchFiles`, `downloadPdfBytes`, dan `signDocument`.

## Comments

- **2026-11-20:** Proyek Flutter `app/` berhasil diinisialisasi beserta dependencies MVP (`flutter_riverpod`, `dio`, `pdfrx`, `signature`, `path_provider`, `shared_preferences`), model domain (`VaultPdfFile`, `SignaturePlacement`, `SignDocumentResult`), dan `MyAcrobatApiClient`. Diverifikasi dengan TDD (`5 passed` di `app/test/api_client_and_models_test.dart`).
