# Panduan Deployment & Distribusi MyAcrobat (Terintegrasi di Syncro ERP & Standalone)

Dokumen ini menjelaskan langkah operasional **MyAcrobat** yang kini sudah terintegrasi penuh sebagai **Native Laravel Module (`Modules/MyAcrobat`) di dalam `syncro_erp`**, maupun opsi standalone Node.js jika dibutuhkan.

---

## 0. Mode Terintegrasi Laravel `syncro_erp` (Rekomendasi Utama — Tanpa Server Node.js)

Seluruh fitur backend **MyAcrobat** kini telah menjadi modul native Laravel di `C:\laragon\www\syncro_erp\Modules\MyAcrobat`.

### Keunggulan Mode Ini:
- **Satu Server & Satu Domain dengan Syncro ERP:** Tidak perlu menjalankan proses Node.js / PM2 terpisah di port `3000`.
- **Endpoint Kompatibel Langsung dengan Aplikasi Flutter MyAcrobat:**
  - Prefix kompatibel langsung: `https://<domain-syncro-erp>/api/auth/login`, `/api/me`, `/api/me/signature`, `/api/files`, `/api/files/{fileId}/download`, `/api/files/{fileId}/sign`
  - Prefix standar modul Syncro: `https://<domain-syncro-erp>/api/v1/myacrobat/...`
  - Dashboard Web di dalam Syncro ERP: `https://<domain-syncro-erp>/myacrobat`

### Variabel `.env` di `syncro_erp/.env`:
Tambahkan (opsional, default sudah `/Testing`):
```ini
MEGA_ROOT_FOLDER=/Testing
MEGACMD_BIN_DIR=
```

### Catatan Penting di aaPanel (PHP-FPM + MEGAcmd):
1. Pastikan fungsi PHP `proc_open` dan `proc_close` **tidak diblokir** di **aaPanel -> App Store -> PHP 8.x -> Disabled functions** (hapus `proc_open` dari daftar *Disabled functions* karena Symfony Process membutuhkannya untuk memanggil `mega-ls`, `mega-get`, `mega-put`).
2. Karena PHP-FPM di aaPanel berjalan sebagai user Linux **`www`**, pastikan sesi login `MEGAcmd` dijalankan untuk user `www` (atau arahkan `HOME` / sesi `.megaCmd` agar dapat diakses user `www`):
   ```bash
   sudo -u www -H mega-login email-mega-kantor@domain.com 'PasswordMegaAnda'
   sudo -u www -H mega-whoami
   sudo -u www -H mega-ls -l /Testing
   ```
3. Di aplikasi Flutter **MyAcrobat** (ikon Roda Gigi **Pengaturan Server Kantor**), cukup isi **URL Server Kantor** dengan URL Laravel `syncro_erp` Anda (misalnya `http://10.19.83.141:8000` saat lokal atau `https://syncro.perusahaan.com` saat produksi).

---

## 1. Konfigurasi `.env` Standalone Node.js (Opsional)

1. Masuk ke folder `backend/`:
   ```powershell
   cd C:\laragon\www\MyAcrobat\backend
   copy .env.example .env
   ```
2. Edit file `backend/.env` dan sesuaikan folder **Mega.nz Cloud Vault** serta koneksi database **Syncro ERP**:
   ```ini
   PORT=3000
   HOST=0.0.0.0
   MEGA_ROOT_FOLDER=Testing
   MEGACMD_BIN_DIR=
   SYNCRO_DB_URL=postgresql://postgres:@127.0.0.1:5432/syncro
   SYNCRO_PUBLIC_STORAGE_DIR=/www/wwwroot/syncro_erp/storage/app/public
   AUTH_TOKEN_SECRET=ganti-dengan-secret-acak-kantor
   PUBLIC_WEB_DIR=./public
   ```

---

## 2. Deploy ke Server Linux dengan aaPanel + MEGAcmd

### Langkah A: Instal MEGAcmd di Server Linux (Ubuntu / Debian)
Buka **Terminal** di aaPanel (atau SSH ke server sebagai `root`). Contoh untuk **Ubuntu 22.04** (ganti `xUbuntu_22.04` ke `xUbuntu_24.04` atau `Debian_12` sesuai OS server Anda):

```bash
# Cek versi Ubuntu/Debian server
lsb_release -a

# Download dan instal paket resmi MEGAcmd (contoh Ubuntu 22.04 amd64)
wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb
sudo apt update
sudo apt install -y ./megacmd-xUbuntu_22.04_amd64.deb

# Cek apakah binary mega-ls, mega-get, mega-put sudah masuk PATH (/usr/bin)
which mega-ls
```

### Langkah B: Login Akun Mega 1 Kali di Server
> **PENTING (User Linux harus sama):** Sesi `MEGAcmd` (`~/.megaCmd`) tersimpan per user Linux. Jika di aaPanel Node Project Anda memilih **User = `root`**, jalankan `mega-login` sebagai `root`. Jika memilih **User = `www`**, pastikan `/home/www` ada atau gunakan `root`.

```bash
# Login 1 kali (sebagai root)
mega-login email-mega-kantor@domain.com 'PasswordMegaAnda'

# Verifikasi sesi aktif dan pastikan folder Testing terlihat
mega-whoami
mega-ls -l /Testing
```

### Langkah C: Upload & Build Backend di aaPanel
1. Upload/clone folder proyek ke `/www/wwwroot/MyAcrobat`.
2. Di terminal aaPanel:
   ```bash
   cd /www/wwwroot/MyAcrobat/backend
   cp .env.example .env
   nano .env
   ```
   Pastikan isi `.env`:
   - `MEGA_ROOT_FOLDER=Testing`
   - `MEGACMD_BIN_DIR=/usr/bin` (atau kosongkan karena `/usr/bin` sudah ada di `PATH`)
   - `SYNCRO_DB_URL=postgresql://user_db:pass_db@127.0.0.1:5432/syncro`
   - `SYNCRO_PUBLIC_STORAGE_DIR=/www/wwwroot/syncro_erp/storage/app/public`
3. Install dependencies & build TypeScript:
   ```bash
   cd /www/wwwroot/MyAcrobat/backend
   npm install
   npm run build
   ```

### Langkah D: Daftarkan di Menu Node Project aaPanel
1. Buka dashboard **aaPanel -> Website -> Node project -> Add Node project**.
2. Isi konfigurasi berikut:
   - **Path:** `/www/wwwroot/MyAcrobat/backend`
   - **Name:** `myacrobat-backend`
   - **Run opt:** `start` (menjalankan `node dist/server.js` dari `package.json`)
   - **Port:** `3000` (centang **Release Port** agar terbuka di firewall aaPanel, atau gunakan Reverse Proxy domain/subdomain)
   - **User:** **`root`** *(wajib sama dengan user Linux yang dipakai saat `mega-login` di Langkah B)*
   - **Node version:** Pilih Node.js `v20` atau `v22`
   - **Boot:** Centang (agar otomatis menyala saat server reboot)
3. Klik **Confirm / Submit**, lalu cek `http://<IP-atau-Domain-Server>:3000/health`.

*(Tip agar daemon MEGAcmd otomatis menyala saat VPS reboot: tambahkan Cron di aaPanel bertipe **Shell Script** atau `@reboot` di `crontab -e` milik `root`: `@reboot /usr/bin/mega-whoami >/dev/null 2>&1`)*.

---

## 3. Menjalankan Backend di Server Kantor Windows (Alternatif tanpa aaPanel)

### Opsi A: Windows Server / PC Server Kantor (Laragon + PM2)

Jalankan script satu langkah berikut (disarankan klik kanan **Run as Administrator** pada kali pertama agar port `3000` dibuka di Windows Firewall):

```powershell
.\scripts\start-office-server.bat
```

Atau secara manual menggunakan **PM2**:

```powershell
cd C:\laragon\www\MyAcrobat\backend
npm install
npm run build
pm2 start ecosystem.config.cjs
pm2 save
```

Cek status server:
- Health check: `http://<IP-Server-Kantor>:3000/health`
- Aplikasi Web (bila `backend/public/` sudah terisi hasil build Flutter Web): `http://<IP-Server-Kantor>:3000/`

### Opsi B: Docker / Docker Compose (Linux atau Windows Server)

```bash
docker compose up -d --build
```

---

## 3. Membuat Paket Rilis Aplikasi (`.apk`, Windows Desktop, & Web)

Gunakan script `scripts/build-release.ps1` (Windows) atau `scripts/build-release.sh` (Linux/macOS) dengan menyertakan IP LAN Server Kantor sebagai default `API_BASE_URL`:

```powershell
.\scripts\build-release.ps1 -ApiBaseUrl "http://192.168.1.100:3000"
```

Atau di Linux/macOS:

```bash
bash ./scripts/build-release.sh "http://192.168.1.100:3000"
```

Hasil build akan ditempatkan pada:
1. **Android APK (`dist/MyAcrobat-release.apk`)**: Bagikan ke ponsel pegawai melalui WhatsApp / Intranet kantor.
2. **Windows Desktop (`dist/MyAcrobat-windows.zip`)**: Ekstrak dan jalankan di PC staf kantor.
3. **Web App (`backend/public/`)**: Otomatis disajikan oleh Fastify di `http://<IP-Server-Kantor>:3000/` sehingga pengguna PC, Mac, atau iPhone di jaringan Wi-Fi/LAN kantor dapat langsung mengakses tanpa instalasi.

---

## 4. Mengubah Alamat IP Server Kantor Tanpa Build Ulang

Jika suatu saat alamat IP LAN Server Kantor berubah (misalnya dari `http://192.168.1.100:3000` menjadi `http://192.168.1.250:3000`):
1. Buka aplikasi **MyAcrobat**.
2. Pada layar **Daftar Dokumen**, ketuk ikon **Pengaturan Server Kantor** (ikon roda gigi di pojok kanan atas AppBar).
3. Masukkan URL Server Kantor baru (contoh: `http://192.168.1.250:3000`) lalu tekan **Simpan**.
4. Aplikasi akan menyimpan alamat baru secara permanen di perangkat (`shared_preferences`) dan langsung memuat ulang daftar dokumen dari server baru.
