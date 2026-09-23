// Inisialisasi Firebase dan alur masuk, dipakai halaman anotasi maupun
// halaman pemantauan.
//
// Anotator tidak punya akun Google di sini. Mereka mengetik kode, Cloud
// Function menukarnya dengan custom token, dan klaim di dalam token itulah yang
// dibaca aturan keamanan.
import { initializeApp } from "https://www.gstatic.com/firebasejs/12.3.0/firebase-app.js";
import {
  getAuth, signInWithCustomToken, signOut, onAuthStateChanged,
  setPersistence, browserLocalPersistence,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-auth.js";
import {
  initializeFirestore, persistentLocalCache, persistentMultipleTabManager,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-firestore.js";
import { getStorage } from "https://www.gstatic.com/firebasejs/12.3.0/firebase-storage.js";
import {
  getFunctions, httpsCallable,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-functions.js";
import { KONFIG, WILAYAH, VERSI } from "./firebase-konfig.js";

export const app = initializeApp(KONFIG);
export const auth = getAuth(app);
export const storage = getStorage(app);
export const fungsi = getFunctions(app, WILAYAH);
export { VERSI };

// Cache lokal yang bertahan: jawaban tetap tersimpan ketika jaringan putus, dan
// pengelola banyak tab dipakai supaya membuka tab kedua tidak melempar galat.
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
});

setPersistence(auth, browserLocalPersistence);

/**
 * Tukar kode dengan custom token, lalu masuk.
 * @param {string} kode Kode yang diketik pengguna.
 * @return {Promise<{idAnotator: string, nama: string, peran: string}>}
 */
export async function masuk(kode) {
  const panggil = httpsCallable(fungsi, "masukAnotator");
  const jawab = await panggil({ kode });
  await signInWithCustomToken(auth, jawab.data.token);
  return jawab.data;
}

export function keluar() {
  return signOut(auth);
}

/**
 * Klaim pada token yang sedang berlaku.
 * @param {import("https://www.gstatic.com/firebasejs/12.3.0/firebase-auth.js").User} pengguna
 * @return {Promise<{idAnotator: string, peran: string}>}
 */
export async function klaim(pengguna) {
  const hasil = await pengguna.getIdTokenResult();
  return {
    idAnotator: hasil.claims.idAnotator || pengguna.uid,
    peran: hasil.claims.peran || "",
  };
}

/**
 * Jalankan `siap` begitu status masuk diketahui.
 * @param {(pengguna: object|null) => void} siap Penerima status.
 */
export function pantauMasuk(siap) {
  onAuthStateChanged(auth, siap);
}

/**
 * Ubah galat Cloud Function menjadi kalimat yang dapat dibaca anotator.
 * @param {*} galat Galat dari httpsCallable.
 * @return {string} Pesan berbahasa Indonesia.
 */
export function pesanGalat(galat) {
  const detik = galat && galat.details && galat.details.detikTunggu;
  if (galat && galat.code === "functions/resource-exhausted") {
    const menit = Math.ceil((detik || 900) / 60);
    return `Terlalu banyak percobaan. Coba lagi dalam ${menit} menit.`;
  }
  if (galat && galat.code === "functions/permission-denied") {
    return "Kode tidak dikenali. Periksa kembali huruf dan angkanya.";
  }
  if (galat && galat.code === "functions/unavailable") {
    return "Tidak dapat menghubungi server. Periksa jaringan lalu coba lagi.";
  }
  // Kode benar tetapi server gagal menyelesaikan permintaan. Menyuruh anotator
  // memeriksa jaringannya hanya menyesatkan, sebab jaringannya baik-baik saja.
  if (galat && galat.code === "functions/internal") {
    return "Kode benar, tetapi layanan masuk sedang bermasalah. " +
           "Beri tahu peneliti, jangan ulangi terus.";
  }
  return "Terjadi kendala. Coba lagi sebentar.";
}

/** Waktu relatif berbahasa Indonesia, untuk halaman pemantauan. */
export function waktuRelatif(tanggal) {
  if (!tanggal) return "belum pernah";
  const detik = Math.round((Date.now() - tanggal.getTime()) / 1000);
  if (detik < 60) return "baru saja";
  if (detik < 3600) return `${Math.floor(detik / 60)} menit lalu`;
  if (detik < 86400) return `${Math.floor(detik / 3600)} jam lalu`;
  return `${Math.floor(detik / 86400)} hari lalu`;
}
