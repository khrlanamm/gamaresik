# Web anotasi ulang

Antarmuka untuk dua anotator independen yang melabeli ulang 445 citra
penelitian secara buta, supaya naskah dapat melaporkan kesepakatan
antaranotator (Cohen's kappa) dan menjawab pertanyaan penguji tentang asal
ground truth.

## Isi

| Berkas | Guna |
|---|---|
| `publik/index.html` | Halaman anotator: satu citra, tiga tombol kategori. |
| `publik/pantau.html` | Halaman peneliti: kemajuan kedua anotator, tanpa label. |
| `publik/404.html` | Halaman galat alamat. |
| `publik/aset/bersama.js` | Inisialisasi Firebase, masuk dengan kode, pesan galat. |
| `publik/aset/anotasi.js` | Alur anotasi, penyimpanan otomatis, pintasan papan tik. |
| `publik/aset/pantau.js` | Langganan langsung ke `anotasi_kemajuan`. |
| `publik/aset/gaya.css` | Tata letak gelap, ponsel lebih dahulu. |
| `publik/aset/firebase-konfig.js` | Konfigurasi Web App dan jumlah citra. |

Cloud Function penukar kode berada di `../functions-anotasi/`, codebase
`anotasi`, terpisah dari `classifyWaste` supaya penerapan salah satunya tidak
pernah menerapkan yang lain.

Penyiapan data, pembuatan akun, penarikan hasil, dan penghitungan kappa berada
di repositori eksperimen: `src/anotasi_siapkan.py`, `src/anotasi_akun.py`,
`src/anotasi_tarik.py`, dan `src/kesepakatan.py`.

## Cara kerja masuk

Anotator tidak punya akun Google. Mereka mengetik kode, callable
`masukAnotator` membandingkannya dengan turunan PBKDF2-SHA256 210.000 iterasi
pada `anotasi_akun/{id}`, lalu mengembalikan custom token berisi klaim
`anotator`, `peran`, dan `idAnotator`. Aturan keamanan hanya membaca klaim itu.

Kode tidak pernah berada di dalam berkas mana pun di folder ini.

Penjaga percobaan salah bekerja pada dua tingkat, alamat IP dan seluruh situs:
enam kegagalan dalam 15 menit mengunci 15 menit, dan penguncian berikutnya
berlipat sampai 60 menit. Setiap penolakan ditunda 300 ms dan seluruh akun
selalu diperiksa, sehingga lama jawaban tidak membocorkan kode mana yang ada.

## Kebutaan

Kebutaan dijaga di tingkat data, bukan di tingkat antarmuka.

- `anotasi_katalog/{kode}` hanya memuat kode, jalur citra, ukuran, penanda
  himpunan uji, dan kunci urut. Tidak ada satu pun medan kategori di sana.
- Label awal penelitian tidak pernah diunggah ke Firestore. Berkas emasnya,
  `hasil/katalog_anotasi.csv`, tetap berada di komputer peneliti.
- Dokumen jawaban tertutup bagi peneliti. Yang terbaca hanyalah
  `anotasi_kemajuan/{id}`, yang memuat cacah saja.
- Akun peneliti memperoleh klaim `anotator: false`, sehingga aturan Storage
  menolak permintaannya atas citra.

Urutan citra berbeda untuk tiap anotator. Urutan itu datang dari
`kunci[idAnotator]` pada katalog, yaitu SHA-256 dari benih tetap, identitas
anotator, dan kode citra, sehingga dapat diulang dan diperiksa kembali.

## Menerapkan

Berurutan, dan tidak pernah dengan `firebase deploy` tanpa `--only`, sebab
`classifyWaste` milik aplikasi Flutter berada pada proyek yang sama:

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
firebase deploy --only functions:anotasi:masukAnotator
firebase hosting:channel:deploy pratinjau     # uji dahulu
firebase deploy --only hosting
```

## Memeriksa sebelum diserahkan

1. Masuk dengan kedua kode di kanal pratinjau, nilai lima citra, tutup
   peramban, buka lagi, dan pastikan lanjut dari citra keenam.
2. Masuk dengan kode salah enam kali dan pastikan terkunci.
3. Buka panel jaringan peramban dan pastikan tidak ada muatan yang memuat
   kategori.
4. Masuk sebagai anotator pertama, lalu coba membaca jawaban anotator kedua
   lewat konsol, dan pastikan ditolak aturan.
5. Matikan jaringan, nilai tiga citra, hidupkan lagi, dan pastikan ketiganya
   terkirim.

## Peta citra

Tombol **Peta** membuka kisi 445 kotak bernomor, satu kotak per citra menurut
urutan anotator itu sendiri. Warna kotak menyatakan kategori yang ia pilih,
titik kuning menandai ragu, dan garis kecil menandai catatan. Mengetuk kotak
melompat ke citra itu, sehingga jawaban yang telanjur salah dapat diperbaiki
tanpa menekan tombol mundur puluhan kali. Saringan Belum, Ragu, dan Bercatatan
mempersempit kisi, dan kolom nomor melompat langsung.

Peta hanya memuat jawaban anotator itu sendiri. Ia tidak memuat label awal
penelitian maupun jawaban anotator lain.

## Pintasan papan tik

`1` organik · `2` recycle bersih · `3` residu · `U` tandai ragu · `C` catatan ·
`Z` perbesar citra · `P` peta citra · `←` dan `→` pindah citra · `?` pedoman.
