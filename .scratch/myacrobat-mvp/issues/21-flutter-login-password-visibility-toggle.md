# 21 — Tambah Tombol Icon Mata (Show/Hide Password) di Input Password

Status: done
Type: task
Blocked by: -

## Tujuan & Ruang Lingkup

Menambahkan fitur toggle tampilkan/sembunyikan password berupa tombol icon mata (`IconButton`) di dalam kotak input password (`suffixIcon`) pada `app/lib/src/features/auth/login_screen.dart`.

## Detail Pekerjaan

1. **State Visibilitas Password (`_LoginScreenState` di `app/lib/src/features/auth/login_screen.dart`):**
   - Tambahkan field state `bool _obscurePassword = true;`.
2. **Input Password (`Key('login_password_input')`, baris 167-201):**
   - Ganti `obscureText: true` menjadi `obscureText: _obscurePassword`.
   - Tambahkan `suffixIcon` pada `InputDecoration`:
     ```dart
     suffixIcon: IconButton(
       key: const Key('login_password_visibility_toggle'),
       tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
       icon: Icon(
         _obscurePassword ? Icons.visibility_off : Icons.visibility,
         color: const Color(0xFF64748B),
       ),
       onPressed: () {
         setState(() => _obscurePassword = !_obscurePassword);
       },
     ),
     ```

## Seam & Rencana Pengujian (TDD)

- **File Test:** `app/test/syncro_auth_and_signature_sync_test.dart`
- **Skenario Test:**
  1. Saat awal render, `TextField(Key('login_password_input'))` memiliki `obscureText == true` dan icon `Icons.visibility_off` tampil di `Key('login_password_visibility_toggle')`.
  2. Setelah tap `Key('login_password_visibility_toggle')`, `obscureText` berubah menjadi `false` dan icon berubah menjadi `Icons.visibility`.
  3. Tap sekali lagi mengembalikan `obscureText == true` dan icon `Icons.visibility_off`.
- **Verifikasi:**
  - `flutter analyze --no-pub` -> 0 errors, 0 warnings.
  - `flutter test --no-pub test/syncro_auth_and_signature_sync_test.dart` lulus.

## Acceptance Criteria

- [x] Secara default, teks password tetap tersembunyi (`obscureText == true`).
- [x] Terdapat icon mata di sisi kanan dalam kotak input password (`suffixIcon`).
- [x] Menekan icon mata men-toggle visibilitas password antara tersembunyi dan terlihat.
- [x] Widget test untuk toggle visibilitas password lulus.
