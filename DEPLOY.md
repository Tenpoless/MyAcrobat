# Panduan Deployment & Distribusi MyAcrobat (Server Kantor)

Dokumen ini menjelaskan langkah instalasi dan operasional **MyAcrobat** di **Server Kantor** (Windows Server / PC Server dengan Laragon & PM2, atau Linux Server dengan PM2 / Docker), serta cara mendistribusikan aplikasi ke perangkat pengguna di jaringan kantor.

---

## 1. Konfigurasi `.env` di Server Kantor

1. Masuk ke folder `backend/`:
   ```powershell
   cd C:\laragon\www\MyAcrobat\backend
   copy .env.example .env
   ```
2. Edit file `backend/.env` dan sesuaikan kredensial **Mega.nz Cloud Vault** serta koneksi database **Syncro ERP**:
   ```ini
   PORT=3000
   HOST=0.0.0.0
   MEGA_EMAIL=akun-mega-kantor@perusahaan.com
   MEGA_PASSWORD=password-mega-kantor
   MEGA_ROOT_FOLDER=MyAcrobat
   SYNCRO_DB_URL=postgresql://postgres:@127.0.0.1:5432/syncro_erp
   SYNCRO_PUBLIC_STORAGE_DIR=C:/laragon/www/syncro_erp/storage/app/public
   AUTH_TOKEN_SECRET=ganti-dengan-secret-acak-kantor
   PUBLIC_WEB_DIR=./public
   ```

---

## 2. Menjalankan Backend di Server Kantor

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
