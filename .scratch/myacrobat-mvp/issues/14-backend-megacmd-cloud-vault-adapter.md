# 14 — Migrasi `CloudVaultAdapter` dari `megajs` ke `MEGAcmd` (`MegaCmdCloudVaultAdapter`)

Status: resolved
Type: task
Blocked by: 02, 04, 05

## Tujuan & Ruang Lingkup

Mengganti implementasi penyimpanan Mega.nz di backend dari library tidak resmi `megajs` (yang memicu *malicious login account lock* pada Mega.nz) ke **`MegaCmdCloudVaultAdapter`** berbasis CLI resmi **MEGAcmd** (`MEGAclient.exe` di Windows / `mega-*` di Linux) yang menggunakan satu sesi login persisten di daemon `MEGAcmdServer`, tanpa mengubah kontrak REST API maupun aplikasi Flutter.

## Detail Pekerjaan

1. **Konfigurasi Environment (`backend/src/config.ts`, `backend/.env.example`, `backend/.env`):**
   - Hapus kewajiban variabel `MEGA_EMAIL` dan `MEGA_PASSWORD` pada `loadConfig()` karena sesi login Mega dikelola satu kali melalui daemon `MEGAcmdServer` (`login` di `MEGAcmdShell`).
   - Tambahkan properti `megacmdBinDir: string` (dibaca dari `MEGACMD_BIN_DIR`, opsional; default otomatis mendeteksi `%LOCALAPPDATA%\MEGAcmd` di Windows atau `PATH` sistem) dan pertahankan `megaRootFolder: string` (`MEGA_ROOT_FOLDER`, contoh: `Testing`).

2. **Implementasi `MegaCmdCloudVaultAdapter` (`backend/src/vault/cloud-vault.ts`):**
   - Menggantikan `MegaCloudVaultAdapter` (`megajs`) dengan `MegaCmdCloudVaultAdapter implements CloudVault`.
   - Menyediakan *seam* `MegaCmdCommandRunner` yang dapat di-inject untuk unit test TDD (default menjalankan `MEGAclient.exe <subcommand> ...` di Windows atau `mega-<subcommand> ...` di Linux/macOS menggunakan `child_process.execFile`).
   - **Encoding `fileId`:** Menggunakan `encodeFileNameToId(name)` / `decodeFileIdToName(fileId)` berbasis `base64url` dari nama file PDF di dalam folder target sehingga aman dipakai pada route `/api/files/:fileId/download` dan `/api/files/:fileId/sign`.
   - **`listPdfFiles()`:**
     - Menjalankan `ls -l --time-format=ISO6081 <remoteFolder>` (atau parsing output standar `ls -l` MEGAcmd).
     - Menyaring hanya baris file (bukan direktori `d...`) yang berakhiran `.pdf` (case-insensitive), memetakan `fileId`, `name`, `size`, `updatedAt` (ISO-8601), dan `isSigned: isSignedPdfName(name)`, diurutkan dari yang terbaru.
   - **`downloadPdf(fileId)`:**
     - Memvalidasi keberadaan file PDF di folder target (melempar `VaultFileNotFoundError` jika tidak ditemukan).
     - Mengunduh file dengan `get <remoteFilePath> <tempDir>`, membaca `Uint8Array`, dan selalu membersihkan `<tempDir>` di blok `finally`.
   - **`uploadSignedPdf(sourceFileId, signedPdfBytes)`:**
     - Mengambil daftar file di folder target, memvalidasi `sourceFileId` (melempar `VaultFileNotFoundError` bila tidak ada), lalu menghitung nama baru non-destruktif (`<nama>_signed.pdf`, `_signed_2.pdf`, dst.) menggunakan `resolveSignedFileName()`.
     - Menulis `signedPdfBytes` ke `<tempDir>/<signedFileName>`, menjalankan `put <localTempFile> <remoteFolder>/`, membersihkan `<tempDir>`, dan mengembalikan metadata `VaultPdfFile` untuk file yang baru diunggah.
   - **Penanganan Error Sesi MEGAcmd:**
     - Jika MEGAcmd mengembalikan status belum login (`Not logged in` / exit code non-zero), lempar pesan error yang jelas agar admin menjalankan `login` satu kali di `MEGAcmdShell`.

3. **Wiring Server (`backend/src/server.ts`) & Pembersihan `megajs`:**
   - Memasang `MegaCmdCloudVaultAdapter` di `backend/src/server.ts`.
   - Menghapus ketergantungan runtime pada `megajs` dari kode sumber backend.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/cloud-vault.test.ts` & `backend/tests/config-and-health.test.ts`
- **Skenario Test (Red → Green):**
  1. `loadConfig({})` berhasil tanpa `MEGA_EMAIL` / `MEGA_PASSWORD` dan membaca `MEGA_ROOT_FOLDER` serta `MEGACMD_BIN_DIR`.
  2. `listPdfFiles()` mem-parsing output `ls -l` MEGAcmd (termasuk nama file dengan spasi seperti `Welcome to MEGA.pdf`), mengabaikan folder dan file non-PDF, serta mengisi `isSigned` dengan benar.
  3. `downloadPdf(fileId)` menjalankan subcommand `get` ke folder temporer, mengembalikan bytes PDF, dan melempar `VaultFileNotFoundError` jika `fileId` tidak valid/tidak ditemukan.
  4. `uploadSignedPdf(sourceFileId, signedPdfBytes)` menghitung nama non-destruktif `_signed.pdf` / `_signed_2.pdf` menggunakan `resolveSignedFileName()`, menjalankan subcommand `put`, dan mengembalikan `VaultPdfFile` baru (`isSigned: true`).
  5. Melempar error informatif ketika MEGAcmd belum login (`Not logged in`).

## Acceptance Criteria

- [x] `loadConfig()` tidak lagi mewajibkan `MEGA_EMAIL` dan `MEGA_PASSWORD`.
- [x] `MegaCmdCloudVaultAdapter` menggantikan `megajs` dan mengimplementasikan kontrak `CloudVault` (`listPdfFiles`, `downloadPdf`, `uploadSignedPdf`).
- [x] Seluruh unit & integration test di `backend/` lulus (`npm --prefix backend test`).

## Comments

- Selesai diimplementasikan dengan TDD (`7 passed` pada `cloud-vault.test.ts`, total `29 passed` di seluruh suite `backend/`).
