# 15 — Revisi Header, Judul Kartu, Subjudul, dan Penghapusan Footer Server pada `LoginScreen`

Status: resolved
Type: task
Blocked by: 13

## Tujuan & Ruang Lingkup

Menyederhanakan tampilan hierarki visual dan teks informasi pada layar login (`app/lib/src/features/auth/login_screen.dart`) sesuai permintaan pengguna (poin revisi 1, 2, 3, dan 7) tanpa mengubah alur autentikasi atau tombol pengaturan server di AppBar.

## Detail Pekerjaan

1. **Poin 1 — Header AppBar (`login_screen.dart`):**
   - Ubah judul `AppBar` dari `'MyAcrobat: Login Syncro ERP'` menjadi **`'MyAcrobat'`**.
   - Posisikan judul tepat di tengah (`centerTitle: true`).
   - Ubah warna teks judul dan ikon pada `AppBar` menjadi hitam (`Colors.black`) dengan latar belakang terang (`Colors.white`) agar teks `'MyAcrobat'` berwarna hitam memiliki kontras WCAG AA yang jelas.
2. **Poin 2 — Judul Kartu Login (`login_screen.dart`):**
   - Ubah judul utama di dalam kartu login dari `'Masuk dengan Akun Syncro ERP'` menjadi **`'Login'`**.
3. **Poin 3 — Subjudul / Keterangan Kartu Login (`login_screen.dart`):**
   - Hapus teks `'Gunakan NIK (username) atau Email Syncro ERP untuk mengakses dokumen PDF Mega.nz dan menyinkronkan tanda tangan Anda.'`.
   - Ganti dengan **`'Email / Username dan Password yang sama dengan akun syncro'`**.
4. **Poin 7 — Hapus Keterangan Footer Server Kantor (`login_screen.dart`):**
   - Hapus widget teks `'Server Kantor: ${apiClient.baseUrl}'` di bagian bawah tombol submit login.

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test (Red → Green):**
  1. Memastikan `AppBar` pada `LoginScreen` memiliki `centerTitle == true`, menampilkan judul `'MyAcrobat'` dengan warna hitam (`Colors.black`), dan tidak lagi menampilkan `'MyAcrobat: Login Syncro ERP'`.
  2. Memastikan kartu login menampilkan judul `'Login'` dan keterangan `'Email / Username dan Password yang sama dengan akun syncro'`.
  3. Memastikan teks `'Server Kantor:'` tidak lagi dirender pada `LoginScreen`.

## Acceptance Criteria

- [x] Header `AppBar` menampilkan `'MyAcrobat'` di tengah (`centerTitle: true`) dengan warna teks hitam.
- [x] Judul kartu berubah dari `'Masuk dengan Akun Syncro ERP'` menjadi `'Login'`.
- [x] Keterangan di bawah judul berubah menjadi `'Email / Username dan Password yang sama dengan akun syncro'`.
- [x] Teks `'Server Kantor: http://...'` di bagian bawah kartu login dihapus.
