// Konfigurasi Web App proyek gamaresik.
//
// Nilai di sini bukan rahasia: kunci API web hanyalah pengenal proyek, dan yang
// menjaga data adalah aturan keamanan Firestore serta Storage. Ini berbeda
// dengan kunci service account, yang tidak boleh berada di dalam folder publik
// mana pun.
export const KONFIG = {
  apiKey: "AIzaSyDqMq-YQvQ1uxU1kKlItw0vA4WzfjxxBAs",
  authDomain: "gamaresik.firebaseapp.com",
  projectId: "gamaresik",
  storageBucket: "gamaresik.firebasestorage.app",
  messagingSenderId: "598848553918",
  appId: "1:598848553918:web:941a4943d7bc556ecdefef",
};

export const WILAYAH = "asia-southeast2";
export const VERSI = "anotasi-1.0.0";

// Jumlah citra dalam katalog. Halaman pemantauan memakainya sebagai penyebut,
// sebab peneliti sengaja tidak diberi izin membaca katalog.
export const TOTAL_CITRA = 445;
