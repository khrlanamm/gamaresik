# GamaWaste (`gamaresik`)

Aplikasi Flutter untuk klasifikasi sampah di Universitas Gadjah Mada. Pengguna login dengan Google, memindai sampah dengan kamera, dan mendapatkan rekomendasi kategori beserta warna tempat sampah sesuai standar UGM.

Klasifikasi dijalankan oleh Google Gemini melalui Firebase Cloud Functions — aplikasi tidak pernah memanggil Gemini secara langsung.

## Kategori sampah

| Kategori | Tempat sampah |
| --- | --- |
| Organik Terpilah | Hijau |
| Recycle Bersih Terpilah | Kuning |
| Residu Terpilah | Merah |

## Mekanisme klasifikasi

Mode diatur dari Firestore (`app_config/settings`) tanpa perlu build ulang aplikasi:

- **`zero-shot`** — satu kali inferensi tanpa contoh.
- **`few-shot`** — inferensi dengan contoh tervalidasi dari koleksi `few_shot_data`.
- **`selective`** — selalu zero-shot lebih dulu; jika `confidence_score` di bawah `confidence_threshold`, sistem mengambil `few_shot_count` contoh tervalidasi lalu menjalankan ulang klasifikasi (re-inference).

Koreksi pengguna lewat tombol **"Laporan Hasil Tidak Tepat"** disimpan sebagai contoh tervalidasi, sehingga akurasi few-shot meningkat seiring pemakaian.

## Menjalankan

```bash
flutter pub get
flutter run
```

Backend (perlu akses ke project Firebase `gamaresik`):

```bash
cd functions && npm install
firebase deploy --only functions,firestore,storage
```

## Testing

```bash
flutter analyze          # analisis statis
flutter test             # unit + widget test
cd functions && npm test # logika zero-shot/few-shot/selective (offline)
```

## Konfigurasi & kredensial

Klasifikasi berjalan di **Vertex AI** memakai Application Default Credentials milik Cloud Function itu sendiri — tidak ada API key yang perlu disimpan, dirotasi, atau bisa bocor.

> **Jangan pernah** menambahkan `.env` atau file kredensial apa pun ke daftar `assets:` di `pubspec.yaml` — seluruh isi `assets:` ikut dibungkus ke dalam APK/IPA dan mudah diekstrak.

Biaya Vertex AI ditagihkan ke billing account Blaze project ini. Pastikan `aiplatform.googleapis.com` tetap aktif.

### Build rilis Android

Penandatanganan rilis membaca `android/key.properties` yang menunjuk ke `android/gamaresik-release.jks`. Keduanya gitignored dan **tidak ada di repo** — tanpa file itu, `flutter build apk --release` turun ke debug key dan mencetak peringatan.

```bash
flutter build apk --release
```

SHA-1 dan SHA-256 sertifikat rilis harus terdaftar di Firebase Console (Project Settings → app Android). Kalau tidak, Google Sign-In gagal dengan `ApiException: 10` walau build-nya sukses.

Dokumentasi arsitektur lengkap ada di [CLAUDE.md](CLAUDE.md).
