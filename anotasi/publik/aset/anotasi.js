// Alur anotasi: satu citra pada satu waktu, jawaban tersimpan seketika.
//
// Urutan citra berbeda untuk tiap anotator dan dihitung dari kunci acak yang
// sudah tersimpan pada katalog, sehingga keduanya tidak menilai citra yang sama
// pada waktu yang sama dan tidak ada bias urutan yang dipikul bersama.
import {
  collection, doc, getDoc, getDocs, setDoc, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-firestore.js";
import {
  ref, getDownloadURL,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-storage.js";
import {
  db, storage, masuk, keluar, pantauMasuk, klaim, pesanGalat, VERSI,
} from "./bersama.js";

const KATEGORI = ["organic", "recyclable", "residual"];
const TOMBOL_KE_KATEGORI = { "1": "organic", "2": "recyclable", "3": "residual" };
const PRAMUAT = 5;
const DURASI_MAKS_MS = 120000;   // jeda panjang berarti ditinggal, bukan berpikir

const $ = (id) => document.getElementById(id);
const badan = document.body;

let idAnotator = "";
let daftar = [];            // katalog, sudah diurutkan untuk anotator ini
let antrean = [];           // yang sedang dikerjakan: seluruhnya atau yang ragu
let jawaban = new Map();    // kode -> jawaban tersimpan
let posisi = 0;
let ragu = false;
let mulaiPada = 0;
let menunggu = 0;           // tulisan yang belum sampai ke server
let adaWaktuMulai = false;  // dimulaiPada sudah tercatat pada kemajuan
const alamatCitra = new Map();

// ------------------------------------------------------------------ masuk
$("form-masuk").addEventListener("submit", async (e) => {
  e.preventDefault();
  const tombol = $("tombol-masuk");
  tombol.disabled = true;
  $("galat-masuk").textContent = "";
  try {
    const hasil = await masuk($("kode").value);
    if (hasil.peran === "peneliti") location.href = "/pantau";
  } catch (galat) {
    $("galat-masuk").textContent = pesanGalat(galat);
    tombol.disabled = false;
  }
});

$("tombol-keluar").addEventListener("click", async () => {
  if (menunggu > 0 &&
      !confirm(menunggu + " jawaban belum terkirim. Tetap keluar?")) return;
  await keluar();
  location.reload();
});

pantauMasuk(async (pengguna) => {
  if (!pengguna) { badan.dataset.layar = "masuk"; return; }
  const { idAnotator: id, peran } = await klaim(pengguna);
  if (peran === "peneliti") { location.href = "/pantau"; return; }
  if (peran !== "anotator") { await keluar(); badan.dataset.layar = "masuk"; return; }
  idAnotator = id;
  await mulai();
});

// ------------------------------------------------------------- pemuatan
async function mulai() {
  $("status").textContent = "memuat";
  const [katalog, milik, kemajuan] = await Promise.all([
    getDocs(collection(db, "anotasi_katalog")),
    getDocs(collection(db, "anotasi_jawaban", idAnotator, "jawaban")),
    getDoc(doc(db, "anotasi_kemajuan", idAnotator)),
  ]);

  daftar = katalog.docs
      .map((d) => ({ kode: d.id, ...d.data() }))
      .sort((a, b) => kunci(a).localeCompare(kunci(b)));
  jawaban = new Map(milik.docs.map((d) => [d.id, d.data()]));
  adaWaktuMulai = kemajuan.exists() && Boolean(kemajuan.data().dimulaiPada);

  $("total").textContent = String(daftar.length);
  if (!jawaban.size) $("pedoman").showModal();

  antrean = daftar;
  posisi = daftar.findIndex((c) => !jawaban.has(c.kode));
  if (posisi < 0) { tampilkanSelesai(); return; }
  badan.dataset.layar = "kerja";
  tandaiSimpan();
  await tampilkan();
}

/** Kunci urut milik anotator ini, dengan kode sebagai cadangan. */
function kunci(citra) {
  return (citra.kunci && citra.kunci[idAnotator]) || citra.kode;
}

async function alamat(citra) {
  if (!alamatCitra.has(citra.kode)) {
    alamatCitra.set(citra.kode, getDownloadURL(ref(storage, citra.jalur)));
  }
  return alamatCitra.get(citra.kode);
}

async function tampilkan() {
  if (posisi >= antrean.length) { tampilkanSelesai(); return; }
  const citra = antrean[posisi];
  const tersimpan = jawaban.get(citra.kode);

  ragu = Boolean(tersimpan && tersimpan.ragu);
  $("tombol-ragu").setAttribute("aria-pressed", ragu ? "true" : "false");
  $("catatan").value = (tersimpan && tersimpan.catatan) || "";
  $("kotak-catatan").dataset.buka = $("catatan").value ? "ya" : "tidak";
  $("tombol-mundur").disabled = posisi === 0;
  perbaruiBilah();

  const nomor = daftar.findIndex((c) => c.kode === citra.kode) + 1;
  const gambar = $("citra");
  gambar.alt = "Citra nomor " + nomor + " dari " + daftar.length;
  try {
    gambar.src = await alamat(citra);
  } catch (galat) {
    alamatCitra.delete(citra.kode);
    $("status").textContent = "citra gagal dimuat";
  }
  mulaiPada = Date.now();

  for (let i = 1; i <= PRAMUAT; i++) {
    const depan = antrean[posisi + i];
    if (!depan) break;
    alamat(depan).then((url) => { new Image().src = url; }).catch(() => {});
  }
}

function perbaruiBilah() {
  $("ke").textContent = String(jawaban.size);
  $("bilah-isi").style.width = (jawaban.size / daftar.length) * 100 + "%";
}

// -------------------------------------------------------------- menjawab
async function jawab(kategori) {
  if (!KATEGORI.includes(kategori)) return;
  const citra = antrean[posisi];
  if (!citra) return;

  const isian = {
    kode: citra.kode,
    kategori,
    ragu,
    catatan: $("catatan").value.trim().slice(0, 500),
    durasiMs: Math.min(Math.max(Date.now() - mulaiPada, 0), DURASI_MAKS_MS),
    urutanKe: daftar.findIndex((c) => c.kode === citra.kode) + 1,
    dibuatPada: serverTimestamp(),
    diubahPada: serverTimestamp(),
    versiApp: VERSI,
  };
  jawaban.set(citra.kode, isian);

  // Sengaja tidak ditunggu. Antrean Firestore menjamin pengirimannya, termasuk
  // sesudah jaringan putus, dan anotator langsung maju ke citra berikutnya.
  menunggu += 1;
  tandaiSimpan();
  setDoc(doc(db, "anotasi_jawaban", idAnotator, "jawaban", citra.kode), isian)
      .catch(() => {})
      .finally(() => { menunggu = Math.max(0, menunggu - 1); tandaiSimpan(); });
  simpanKemajuan();

  posisi += 1;
  await tampilkan();
}

function tandaiSimpan() {
  const status = $("status");
  status.dataset.simpan = menunggu ? "menunggu" : "aman";
  status.textContent = menunggu ? "menyimpan " + menunggu : "tersimpan";
}

function simpanKemajuan() {
  const nilai = [...jawaban.values()];
  const detik = nilai.reduce((n, j) => n + (j.durasiMs || 0), 0) / 1000;
  const isian = {
    idAnotator,
    jumlahSelesai: jawaban.size,
    jumlahRagu: nilai.filter((j) => j.ragu).length,
    jumlahCatatan: nilai.filter((j) => j.catatan).length,
    detikAktif: Math.round(detik),
    terakhirAktif: serverTimestamp(),
    selesai: jawaban.size >= daftar.length,
  };
  // Waktu mulai ditulis sekali saja, supaya lamanya pengerjaan tetap terbaca.
  if (!adaWaktuMulai) { isian.dimulaiPada = serverTimestamp(); adaWaktuMulai = true; }
  setDoc(doc(db, "anotasi_kemajuan", idAnotator), isian, { merge: true })
      .catch(() => {});
}

function tampilkanSelesai() {
  const jumlahRagu = [...jawaban.values()].filter((j) => j.ragu).length;
  badan.dataset.layar = "selesai";
  $("selesai-jumlah").textContent = String(jawaban.size);
  $("selesai-rinci").textContent = menunggu
      ? menunggu + " jawaban masih menunggu jaringan. Biarkan halaman terbuka."
      : jumlahRagu + " citra Anda tandai ragu.";
  $("tombol-tinjau").hidden = jumlahRagu === 0;
}

// -------------------------------------------------------------- kendali
document.querySelectorAll(".pilihan button").forEach((b) => {
  b.addEventListener("click", () => jawab(b.dataset.kategori));
});

$("tombol-ragu").addEventListener("click", () => {
  ragu = !ragu;
  $("tombol-ragu").setAttribute("aria-pressed", ragu ? "true" : "false");
});

$("tombol-catatan").addEventListener("click", () => {
  const kotak = $("kotak-catatan");
  kotak.dataset.buka = kotak.dataset.buka === "ya" ? "tidak" : "ya";
  if (kotak.dataset.buka === "ya") $("catatan").focus();
});

$("tombol-mundur").addEventListener("click", async () => {
  if (posisi === 0) return;
  posisi -= 1;
  await tampilkan();
});

$("tombol-pedoman").addEventListener("click", () => $("pedoman").showModal());
$("tutup-pedoman").addEventListener("click", () => $("pedoman").close());

// Peninjauan memakai salinan daftar ragu yang dibekukan saat tombol ditekan,
// sehingga melepas tanda ragu tidak menggeser citra yang belum ditinjau.
$("tombol-tinjau").addEventListener("click", async () => {
  const ragunya = daftar.filter((c) => {
    const j = jawaban.get(c.kode);
    return j && j.ragu;
  });
  if (!ragunya.length) return;
  antrean = ragunya;
  posisi = 0;
  badan.dataset.layar = "kerja";
  await tampilkan();
});

document.addEventListener("keydown", (e) => {
  if (badan.dataset.layar !== "kerja") return;
  if (e.target.tagName === "TEXTAREA" || e.target.tagName === "INPUT") {
    if (e.key === "Escape") e.target.blur();
    return;
  }
  if (TOMBOL_KE_KATEGORI[e.key]) { e.preventDefault(); jawab(TOMBOL_KE_KATEGORI[e.key]); }
  else if (e.key.toLowerCase() === "u") { e.preventDefault(); $("tombol-ragu").click(); }
  else if (e.key.toLowerCase() === "c") { e.preventDefault(); $("tombol-catatan").click(); }
  else if (e.key === "ArrowLeft") { e.preventDefault(); $("tombol-mundur").click(); }
  else if (e.key === "?") { e.preventDefault(); $("pedoman").showModal(); }
});

// Peringatan terakhir bila masih ada jawaban yang belum terkirim.
window.addEventListener("beforeunload", (e) => {
  if (menunggu > 0) { e.preventDefault(); e.returnValue = ""; }
});
