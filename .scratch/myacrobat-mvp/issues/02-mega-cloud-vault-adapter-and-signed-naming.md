# 02 — Modul `CloudVaultAdapter` (`megajs`) & Aturan Penamaan Non-Destruktif `_signed.pdf`

Status: resolved
Type: task
Blocked by: 01

## Tujuan & Ruang Lingkup

Membangun *deep module* `CloudVaultAdapter` di `backend/src/vault/cloud-vault.ts` yang membungkus operasi penyimpanan ke satu akun **Cloud Vault** Mega.nz (`megajs`) serta fungsi murni penamaan file **Signed Document** (`<nama_asli>_signed.pdf`) yang menjamin dokumen asli (**Source Document**) tidak pernah tertimpa.

> **Batasan Tiket:** Tiket ini hanya membangun modul domain `CloudVaultAdapter` beserta helper penamaan `_signed.pdf` dan unit test-nya. Pemasangan ke route HTTP Fastify dilakukan di Tiket 04 dan 05.

## Detail Pekerjaan

1. **Kontrak Interface (`backend/src/vault/cloud-vault.ts`):**
   ```ts
   export interface VaultPdfFile {
     fileId: string;
     name: string;
     size: number;
     updatedAt: string; // ISO-8601
     isSigned: boolean;
   }

   export interface CloudVault {
     listPdfFiles(): Promise<VaultPdfFile[]>;
     downloadPdf(fileId: string): Promise<{ file: VaultPdfFile; bytes: Uint8Array }>;
     uploadSignedPdf(sourceFileId: string, signedPdfBytes: Uint8Array): Promise<VaultPdfFile>;
   }
   ```
2. **Aturan Penamaan Non-Destruktif (`resolveSignedFileName(originalName, existingNames)`):**
   - Mengubah `Surat_Perjanjian.pdf` (atau `.PDF`) menjadi `Surat_Perjanjian_signed.pdf`.
   - Jika pengguna menandatangani ulang file yang sudah berakhiran `_signed.pdf` (mis. `Surat_Perjanjian_signed.pdf`), jangan menumpuk `_signed_signed.pdf`, melainkan gunakan dasar nama file (`Surat_Perjanjian_signed.pdf`), dan bila di folder Mega.nz sudah ada file dengan nama yang sama persis (`Surat_Perjanjian_signed.pdf`), tambahkan sufiks penomoran aman: `Surat_Perjanjian_signed_2.pdf`, `Surat_Perjanjian_signed_3.pdf`, dst., sehingga **tidak ada file yang pernah ditimpa/dihapus**.
3. **Implementasi `MegaCloudVaultAdapter`:**
   - Menggunakan koneksi tunggal `Storage` dari `megajs` (dengan *lazy login* & *singleton session* agar tidak re-login di setiap request).
   - Membaca folder target sesuai `MEGA_ROOT_FOLDER` (atau root akun Mega bila kosong).
   - `listPdfFiles()`: Menyaring hanya node file (bukan folder) yang namanya berakhiran `.pdf` (case-insensitive), mengisi `isSigned: /_signed(_\d+)?\.pdf$/i.test(name)`, diurutkan berdasarkan waktu terbaru.
   - `downloadPdf(fileId)`: Mencari file berdasarkan `nodeId` / `fileId`, melempar `VaultFileNotFoundError` jika tidak ada, dan mengunduh buffer PDF (`Uint8Array`).
   - `uploadSignedPdf(sourceFileId, signedPdfBytes)`: Menentukan nama baru via `resolveSignedFileName()`, mengunggah buffer ke folder yang sama di Mega.nz, dan mengembalikan metadata `VaultPdfFile` baru.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/cloud-vault.test.ts`
- **Skenario Test (Red → Green):**
  1. `resolveSignedFileName('Kontrak.pdf', ['Kontrak.pdf'])` menghasilkan `'Kontrak_signed.pdf'`.
  2. `resolveSignedFileName('Kontrak.pdf', ['Kontrak.pdf', 'Kontrak_signed.pdf'])` menghasilkan `'Kontrak_signed_2.pdf'` (non-destruktif terhadap file `_signed` sebelumnya).
  3. `resolveSignedFileName('Kontrak_signed.pdf', ['Kontrak.pdf', 'Kontrak_signed.pdf'])` menghasilkan `'Kontrak_signed_2.pdf'`.
  4. `listPdfFiles()` hanya mengembalikan file `.pdf` (mengabaikan `.png`, `.docx`, dan subfolder) serta menandai `isSigned: true` secara tepat pada file `*_signed.pdf`.
  5. `downloadPdf(fileId)` melempar `VaultFileNotFoundError` jika `fileId` tidak ditemukan.

## Acceptance Criteria

- [x] Fungsi `resolveSignedFileName()` menangani akhiran `_signed.pdf` dan mencegah penimpaan file yang sudah ada.
- [x] `MegaCloudVaultAdapter` mengimplementasikan interface `CloudVault` (`listPdfFiles`, `downloadPdf`, `uploadSignedPdf`).
- [x] Seluruh unit test di `backend/tests/cloud-vault.test.ts` lulus.

## Comments

- Selesai diimplementasikan dengan TDD (`6 passed` pada `cloud-vault.test.ts`).
