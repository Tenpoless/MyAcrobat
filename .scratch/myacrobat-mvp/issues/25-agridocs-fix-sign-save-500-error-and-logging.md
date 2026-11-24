# 25 — Analisis & Perbaikan Bug HTTP 500 Saat Simpan Dokumen Bertanda Tangan (`AgriDocs`)

Status: done
Type: bug
Blocked by: -

Repo target:
- `C:\laragon\www\syncro_erp` (`Modules/AgriSign`)
- `C:\laragon\www\MyAcrobat` (`app`)

## Gejala Bug

Saat user menandatangani file PDF (contoh pada screenshot: `Lembar Cetak Batch Label QR - ...`) lalu menekan simpan dokumen, aplikasi menampilkan SnackBar error mentah:

```text
Gagal menyimpan dokumen: DioException [bad response]: This exception was thrown because the response has a status code of 500 ...
```

## Hasil Analisis Akar Masalah

1. **Respons 500 dari server tidak berbentuk JSON `{"error": "..."}`:**
   - Di `app/lib/src/features/viewer/pdf_signing_screen.dart` (baris 324–328), client mengecek `(e.response?.data as Map)['error']`. Jika controller `AgriSignFileController::sign()` masuk ke blok `catch (Throwable $e)` (baris 104–106), server seharusnya mengembalikan JSON `{"error": "<pesan>"}` dan SnackBar akan menampilkan pesan tersebut — **bukan** `DioException [bad response]...`.
   - Munculnya `e.toString()` (`DioException [bad response]...`) menandakan salah satu dari tiga hal berikut terjadi di server:
     a. **Error terjadi di luar `try..catch` `sign()`** (mis. `Throwable`/middleware/Laravel Exception Handler) sehingga Laravel membalas `{"message": "Server Error"}` (key `message`, bukan `error`) atau membalas halaman HTML 500 karena `MyAcrobatApiClient` (`Dio(BaseOptions(baseUrl: baseUrl))`) **belum mengirim header `Accept: application/json`**.
     b. **PHP Fatal Error / Nginx-Apache 500/502/504** (tidak tertangkap `try..catch (Throwable $e)`), misalnya `max_execution_time` habis atau `memory_limit` habis saat memproses PDF + upload.
2. **Tidak ada logging di `AgriSignFileController`:**
   - `AgriSignFileController::sign()` (serta `index()` dan `download()`) menangkap `Throwable $e` dan langsung mengembalikan HTTP 500 JSON **tanpa `Log::error(...)`**, sehingga error di endpoint `/sign` tidak meninggalkan jejak di `storage/logs/laravel.log` ketika terjadi di production.
3. **Proses `sign()` melakukan request Google Drive berlapis dalam 1 HTTP call (rawan timeout):**
   - Di `AgriSignFileController::sign()` (baris 87–93): server menjalankan `downloadPdf($fileId)` -> `embedSignatureIntoPdf(...)` (FPDI parse + re-render seluruh PDF) -> `uploadSignedPdf($fileId, $signedPdfBytes)`.
   - Di `GoogleDriveVaultService::uploadSignedPdf()` (baris 201), server memanggil `$this->listPdfFiles()` **lagi** untuk mencari nama file sumber dan daftar nama eksisting, padahal `$downloaded['file']` sudah diperoleh dari `downloadPdf($fileId)` tepat satu langkah sebelumnya. Ini menambah 1 round-trip HTTP eksternal (timeout 30s) di atas download (30s) dan upload (60s), sehingga total waktu mudah melewati `max_execution_time` PHP / timeout reverse proxy dan memicu 500 HTML.
4. **Penanganan error di UI Flutter kurang informatif:**
   - `pdf_signing_screen.dart` hanya membaca `data['error']` (mengabaikan `data['message']`) dan langsung membuang `e.toString()` (stack teks Dio berbahasa Inggris) ke SnackBar user saat response bukan JSON Map.

## Detail Pekerjaan

### 1. Backend (`C:\laragon\www\syncro_erp`)
1. **`Modules/AgriSign/app/Http/Controllers/Api/AgriSignFileController.php`:**
   - Tambahkan `Log::error(...)` pada blok `catch (Throwable $e)` di `sign()` (serta `index()` dan `download()`) dengan konteks `fileId`, `userId`, `message`, dan `exception` agar error production langsung terlacak di `laravel.log`.
2. **`Modules/AgriSign/app/Services/GoogleDriveVaultService.php` & `AgriSignFileController.php`:**
   - Hilangkan pemanggilan ulang `listPdfFiles()` yang tidak perlu jika metadata file sumber sudah tersedia dari `downloadPdf()`, atau optimalkan agar `uploadSignedPdf()` tidak melakukan round-trip ganda yang memicu timeout PHP/proxy.
   - Cek dan pastikan jika terjadi kegagalan parsing PDF pada `PdfSignatureEmbedderService` (mis. PDF hasil export label QR dengan XRef/stream khusus), error tercatat jelas dan mengembalikan pesan JSON terstruktur.

### 2. Mobile App (`C:\laragon\www\MyAcrobat`)
1. **`app/lib/src/api/myacrobat_api_client.dart`:**
   - Tambahkan `headers: <String, dynamic>{'Accept': 'application/json'}` pada `BaseOptions` `Dio` agar Laravel selalu membalas JSON pada error route/middleware/exception handler.
2. **`app/lib/src/features/viewer/pdf_signing_screen.dart`:**
   - Perbarui ekstraksi pesan error di `_handleSaveSignedDocument()` untuk membaca `data['error'] ?? data['message']`, dan tampilkan pesan ringkas yang mudah dipahami user (mis. `'Terjadi kesalahan pada server (HTTP 500). Silakan coba lagi atau hubungi admin.'`) jika respons bukan JSON, bukan `DioException.toString()` mentah.

## Verifikasi

1. Cek `storage/logs/laravel.log` di server production (`syncro.saraswanti.co.id`) untuk memastikan penyebab spesifik pada file `Lembar Cetak Batch Label QR - ...` (timeout, memory, FPDI parser, atau Drive/Apps Script).
2. `php artisan test --filter=AgriSign` lulus, termasuk test baru yang memverifikasi `Log::error` terpanggil saat `sign` gagal dan `uploadSignedPdf` tidak memicu error/timeout tambahan.
3. `flutter test --no-pub` lulus, termasuk test di `save_signed_document_flow_test.dart` untuk respons HTTP 500 JSON (`error` / `message`) maupun non-JSON (tidak menampilkan `DioException [bad response]` mentah).

## Acceptance Criteria

- [ ] Setiap error HTTP 500 di `AgriSignFileController` tercatat di `laravel.log` lengkap dengan konteks `fileId` dan `exception`.
- [ ] Request `MyAcrobatApiClient` selalu mengirim header `Accept: application/json`.
- [ ] Simpan dokumen bertanda tangan pada file `Lembar Cetak Batch Label QR - ...` berhasil, atau jika gagal, user menerima pesan error yang jelas (bukan `DioException [bad response]`).
- [ ] Semua unit/feature test di `syncro_erp` dan `MyAcrobat` lulus.
