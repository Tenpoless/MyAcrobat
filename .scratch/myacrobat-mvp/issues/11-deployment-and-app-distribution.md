# 11 — Konfigurasi Deployment Server Backend (Docker / PM2) & Script Build Distribusi Aplikasi Flutter (`.apk` / Windows / Web)

Status: resolved
Type: task
Blocked by: 05, 10

## Tujuan & Ruang Lingkup

Menyiapkan paket deployment yang dioptimalkan untuk **Server Kantor** (baik Windows Server / PC Server dengan Laragon/PM2 maupun Linux Server kantor di jaringan LAN/Intranet), serta mendukung pengguna untuk mengatur atau menyesuaikan **Alamat IP / URL Server Kantor** langsung dari aplikasi Flutter jika IP server kantor berubah tanpa harus melakukan *build* ulang aplikasi setiap kali.

> **Batasan Tiket:** Tiket ini fokus pada artefak deployment Server Kantor (`ecosystem.config.cjs` PM2, script startup Windows/Server Kantor, penyajian static web di Fastify, pengaturan opsional Server URL di Flutter dengan default IP Server Kantor, script build rilis `.apk` / Windows / Web, dan panduan `DEPLOY.md`).

## Detail Pekerjaan

1. **Konfigurasi Deployment Server Kantor (`backend/`):**
   - `backend/ecosystem.config.cjs` untuk menjalankan backend Node.js sebagai background service permanen (*auto-restart* saat server kantor menyala) menggunakan **PM2** (`pm2 start ecosystem.config.cjs`).
   - `scripts/start-office-server.ps1` & `scripts/start-office-server.bat` untuk kemudahan menjalankan & membuka port firewall (default port `3000`) di Windows Server / PC Server kantor.
   - `backend/Dockerfile` & `docker-compose.yml` sebagai opsi cadangan bila server kantor menggunakan Docker.
   - **Static Web Hosting di Server Kantor (`PUBLIC_WEB_DIR`):** Server Node.js otomatis menyajikan hasil build **Flutter Web** pada root URL (`http://<IP-Server-Kantor>:3000/`) sehingga pegawai kantor di PC/iPhone/HP bisa langsung membuka aplikasi lewat browser tanpa wajib install jika berada di jaringan kantor.
2. **Konfigurasi Alamat Server Kantor & Script Build Distribusi Flutter (`app/` & `scripts/`):**
   - Di aplikasi Flutter, sediakan default `API_BASE_URL` saat build (`--dart-define=API_BASE_URL=http://<IP-Server-Kantor>:3000`), ditambah **pengaturan cepat "Alamat Server Kantor"** (tersimpan di `shared_preferences`) pada layar Daftar Dokumen agar jika IP server kantor berganti (mis. `http://192.168.1.100:3000`), user/IT kantor cukup mengubah IP di aplikasi tanpa perlu build ulang `.apk`.
   - Script `scripts/build-release.ps1` yang menghasilkan:
     - **File Android (`dist/MyAcrobat-release.apk`)** siap edar ke HP pegawai via WhatsApp/LAN kantor.
     - **Aplikasi Windows Desktop (`dist/MyAcrobat-windows.zip`)** siap pakai di PC kantor.
     - **Web Bundle (`backend/public/`)** yang langsung disajikan oleh Server Kantor.
3. **Panduan Operasional Server Kantor (`DEPLOY.md`):**
   - Langkah setup `.env` akun Mega.nz di Server Kantor.
   - Langkah menjalankan service di Server Kantor (Windows/Laragon/PM2) & membuka akses port `3000` di jaringan LAN/Wi-Fi kantor.
   - Cara membagikan file `.apk`, aplikasi Windows, atau link Web lokal ke pengguna kantor.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `backend/tests/production-build-and-static.test.ts`
- **Skenario Test (Red → Green):**
  1. Proses kompilasi TypeScript (`npm run build` di `backend/`) menghasilkan `dist/server.js` tanpa error tipe.
  2. Ketika `PUBLIC_WEB_DIR` dikonfigurasi ke direktori yang berisi `index.html`, request `GET /` pada Fastify menyajikan halaman aplikasi web tersebut sementara `GET /api/files` dan `GET /health` tetap berfungsi normal.
  3. Verifikasi file konfigurasi `Dockerfile`, `docker-compose.yml`, `ecosystem.config.cjs`, dan script build rilis tersedia serta valid.

## Acceptance Criteria

- [x] Tersedia `backend/Dockerfile`, `docker-compose.yml`, dan `backend/ecosystem.config.cjs` (PM2) yang siap dipakai deploy ke server.
- [x] Tersedia script build satu perintah (`scripts/build-release.ps1` & `.sh`) untuk menghasilkan `MyAcrobat-release.apk` dengan `API_BASE_URL` server produksi.
- [x] Tersedia panduan lengkap `DEPLOY.md` untuk deploy server dan cara mengedarkan aplikasi ke user.
- [x] Seluruh test di `backend/tests/production-build-and-static.test.ts` dan `npm run build` lulus.

## Comments

- **2026-11-20 (Resolved):**
  - Menambahkan `PUBLIC_WEB_DIR` pada `backend/src/config.ts` & `backend/.env.example`, serta static web hosting di `backend/src/app.ts` & `backend/src/server.ts` untuk menyajikan hasil build Flutter Web (`index.html` & aset statis) tanpa mengganggu `/health` dan `/api/*`.
  - Menyediakan artefak deployment Server Kantor: `backend/ecosystem.config.cjs`, `backend/Dockerfile`, `docker-compose.yml`, `scripts/start-office-server.ps1`, `scripts/start-office-server.bat`, `scripts/build-release.ps1`, `scripts/build-release.sh`, dan `DEPLOY.md`.
  - Menambahkan pengaturan cepat **"Alamat Server Kantor"** (`shared_preferences`) di `DocumentListScreen` (`app/lib/src/features/files/document_list_screen.dart` & `document_list_provider.dart`).
  - Seluruh test di `backend/tests/production-build-and-static.test.ts` (23/23 backend tests) dan `app/test/document_list_screen_test.dart` (21/21 Flutter tests) lulus.
