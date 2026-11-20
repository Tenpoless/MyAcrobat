# MyAcrobat

MyAcrobat adalah aplikasi pembaca dan penandatangan dokumen PDF (*PDF Reader & Quick E-Signature*) yang terhubung ke satu akun penyimpanan cloud Mega.nz terpusat untuk membuka PDF, membubuhkan tanda tangan yang tersimpan otomatis (*auto-saved*), dan mengunggah kembali hasil tanda tangan sebagai file baru berakhiran `_signed.pdf`.

## Language

### Dokumen & Penyimpanan

**Source Document**:
File PDF asli di folder kerja Mega.nz yang dipilih pengguna untuk dibaca atau ditandatangani; tidak pernah ditimpa (*non-destructive*).
_Avoid_: Original file, raw PDF, template

**Signed Document**:
File PDF baru hasil penempelan tanda tangan secara permanen (*flattened*) yang diberi akhiran `_signed.pdf` (mis. `Kontrak_signed.pdf`) dan diunggah kembali ke folder yang sama di Mega.nz.
_Avoid_: Output PDF, overwritten file, exported PDF

**Cloud Vault**:
Satu akun dan folder kerja Mega.nz terpusat yang diakses melalui kredensial di sisi server untuk menyimpan seluruh *Source Document* dan *Signed Document*.
_Avoid_: User bucket, personal drive, multi-tenant storage

### Pengguna, Role & Tanda Tangan (`syncro_erp` Shared PostgreSQL)

**Syncro User**:
Akun pengguna dari tabel `users` pada database PostgreSQL `syncro_erp` (`id`, `username`/NIK, `name`, `email`, `position`, `signature_path`, `is_active`) yang memiliki hak akses modul melalui tabel `module_role_assignments` (`module_key = 'myacrobat'`).
_Avoid_: Separate account, guest user

**Saved Signature**:
Spesimen tanda tangan pengguna (PNG transparan) yang disinkronkan dua arah antara kolom `users.signature_path` di storage `syncro_erp` (`storage/app/public/signatures/...`) dan cache lokal perangkat (`saved_signature.png`). Saat pertama kali dibuat di MyAcrobat, gambar otomatis disimpan ke `users.signature_path` dan lokal perangkat untuk langsung digunakan kembali (*one-tap reuse*) pada penandatanganan berikutnya tanpa menggambar ulang.
_Avoid_: Digital certificate, PKI signature, stamp

**Signature Pad**:
Kanvas gambar interaktif tempat pengguna menggambar goresan tanda tangan pertama kali atau saat memilih mengganti *Saved Signature*.
_Avoid_: Drawing board, sketch modal

**Signature Placement**:
Posisi dan ukuran satu tanda tangan pada halaman PDF tertentu yang dinyatakan dalam rasio ternormalisasi (`0.0` hingga `1.0`) terhadap lebar dan tinggi halaman (`pageIndex`, `xRatio`, `yRatio`, `widthRatio`, `heightRatio`).
_Avoid_: Pixel offset, screen coordinate, annotation box
