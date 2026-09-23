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
let nomorKode = new Map();  // kode -> nomor urut anotator ini, mulai dari 1
let jawaban = new Map();    // kode -> jawaban tersimpan
let posisi = 0;
let ragu = false;
let mulaiPada = 0;
let menunggu = 0;           // tulisan yang belum sampai ke server
let adaWaktuMulai = false;  // dimulaiPada sudah tercatat pada kemajuan
const alamatCitra = new Map();
const sel = new Map();      // kode -> tombol pada peta

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
  nomorKode = new Map(daftar.map((c, i) => [c.kode, i + 1]));
  jawaban = new Map(milik.docs.map((d) => [d.id, d.data()]));
  adaWaktuMulai = kemajuan.exists() && Boolean(kemajuan.data().dimulaiPada);

  $("total").textContent = String(daftar.length);
  $("lompat").max = String(daftar.length);
  bangunPeta();
  if (!jawaban.size) $("pedoman").showModal();

  const belum = daftar.findIndex((c) => !jawaban.has(c.kode));
  badan.dataset.layar = "kerja";
  posisi = belum < 0 ? daftar.length - 1 : belum;
  tandaiSimpan();
  await tampilkan();
  if (belum < 0) tampilkanSelesai();
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
  if (posisi < 0 || posisi >= daftar.length) return;
  const citra = daftar[posisi];
  const tersimpan = jawaban.get(citra.kode);

  ragu = Boolean(tersimpan && tersimpan.ragu);
  $("tombol-ragu").setAttribute("aria-pressed", ragu ? "true" : "false");
  $("catatan").value = (tersimpan && tersimpan.catatan) || "";
  $("kotak-catatan").dataset.buka = $("catatan").value ? "ya" : "tidak";
  $("tombol-mundur").disabled = posisi === 0;
  $("tombol-maju").disabled = posisi === daftar.length - 1;
  $("nomor").textContent = String(posisi + 1);
  $("panggung").dataset.besar = "tidak";
  perbaruiBilah();
  sorotSel();

  const gambar = $("citra");
  gambar.alt = "Citra nomor " + (posisi + 1) + " dari " + daftar.length;
  try {
    gambar.src = await alamat(citra);
  } catch (galat) {
    alamatCitra.delete(citra.kode);
    $("status").textContent = "citra gagal dimuat";
  }
  mulaiPada = Date.now();

  for (let i = 1; i <= PRAMUAT; i++) {
    const depan = daftar[posisi + i];
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
  const citra = daftar[posisi];
  if (!citra) return;

  const isian = {
    kode: citra.kode,
    kategori,
    ragu,
    catatan: $("catatan").value.trim().slice(0, 500),
    durasiMs: Math.min(Math.max(Date.now() - mulaiPada, 0), DURASI_MAKS_MS),
    urutanKe: posisi + 1,
    dibuatPada: serverTimestamp(),
    diubahPada: serverTimestamp(),
    versiApp: VERSI,
  };
  jawaban.set(citra.kode, isian);
  perbaruiSel(citra.kode);

  // Sengaja tidak ditunggu. Antrean Firestore menjamin pengirimannya, termasuk
  // sesudah jaringan putus, dan anotator langsung maju ke citra berikutnya.
  menunggu += 1;
  tandaiSimpan();
  setDoc(doc(db, "anotasi_jawaban", idAnotator, "jawaban", citra.kode), isian)
      .catch(() => {})
      .finally(() => { menunggu = Math.max(0, menunggu - 1); tandaiSimpan(); });
  simpanKemajuan();

  if (jawaban.size >= daftar.length) { tampilkanSelesai(); return; }
  // Maju ke citra yang belum dinilai, bukan sekadar nomor berikutnya, supaya
  // memperbaiki jawaban lama tidak melemparkan anotator ke tengah pekerjaan.
  const lanjut = daftar.findIndex((c, i) => i > posisi && !jawaban.has(c.kode));
  posisi = lanjut < 0 ? daftar.findIndex((c) => !jawaban.has(c.kode)) : lanjut;
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

// ------------------------------------------------------------ peta citra
function bangunPeta() {
  const kisi = $("kisi");
  const potongan = document.createDocumentFragment();
  sel.clear();
  for (const citra of daftar) {
    const tombol = document.createElement("button");
    tombol.type = "button";
    tombol.className = "sel";
    tombol.textContent = String(nomorKode.get(citra.kode));
    tombol.dataset.kode = citra.kode;
    potongan.appendChild(tombol);
    sel.set(citra.kode, tombol);
    perbaruiSel(citra.kode);
  }
  kisi.replaceChildren(potongan);
  kisi.addEventListener("click", (e) => {
    const tombol = e.target.closest(".sel");
    if (tombol) lompat(Number(tombol.textContent));
  });
}

function perbaruiSel(kode) {
  const tombol = sel.get(kode);
  if (!tombol) return;
  const j = jawaban.get(kode);
  tombol.dataset.keadaan = (j && j.kategori) || "belum";
  tombol.dataset.ragu = j && j.ragu ? "ya" : "tidak";
  tombol.dataset.catatan = j && j.catatan ? "ya" : "tidak";
  tombol.title = "Citra " + nomorKode.get(kode) +
      (j ? " — sudah dinilai" : " — belum dinilai");
  saringSatu(tombol);
  ringkasPeta();
}

function sorotSel() {
  for (const [kode, tombol] of sel) {
    const kini = nomorKode.get(kode) === posisi + 1;
    tombol.setAttribute("aria-current", kini ? "true" : "false");
  }
}

let saringKini = "semua";

function saringSatu(tombol) {
  const sudah = tombol.dataset.keadaan !== "belum";
  const tampil =
      saringKini === "semua" ? true :
      saringKini === "belum" ? !sudah :
      saringKini === "ragu" ? tombol.dataset.ragu === "ya" :
      tombol.dataset.catatan === "ya";
  tombol.hidden = !tampil;
}

function ringkasPeta() {
  const nilai = [...jawaban.values()];
  $("peta-ringkas").textContent =
      `${jawaban.size} dinilai · ${daftar.length - jawaban.size} belum · ` +
      `${nilai.filter((j) => j.ragu).length} ragu`;
}

function bukaPeta() {
  $("peta").showModal();
  sorotSel();
  const kini = sel.get(daftar[posisi] && daftar[posisi].kode);
  if (kini && !kini.hidden) kini.scrollIntoView({ block: "center" });
}

async function lompat(nomor) {
  if (!Number.isFinite(nomor) || nomor < 1 || nomor > daftar.length) return;
  posisi = nomor - 1;
  if ($("peta").open) $("peta").close();
  badan.dataset.layar = "kerja";
  await tampilkan();
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

$("tombol-mundur").addEventListener("click", () => lompat(posisi));
$("tombol-maju").addEventListener("click", () => lompat(posisi + 2));

$("tombol-perbesar").addEventListener("click", perbesar);
$("citra").addEventListener("click", perbesar);

function perbesar() {
  const panggung = $("panggung");
  const besar = panggung.dataset.besar === "ya";
  panggung.dataset.besar = besar ? "tidak" : "ya";
  $("tombol-perbesar").textContent = besar ? "Perbesar" : "Perkecil";
}

$("tombol-peta").addEventListener("click", bukaPeta);
$("tombol-peta-selesai").addEventListener("click", bukaPeta);
$("tutup-peta").addEventListener("click", () => $("peta").close());

document.querySelectorAll(".saring button").forEach((b) => {
  b.addEventListener("click", () => {
    saringKini = b.dataset.saring;
    document.querySelectorAll(".saring button").forEach((lain) => {
      lain.setAttribute("aria-pressed", lain === b ? "true" : "false");
    });
    for (const tombol of sel.values()) saringSatu(tombol);
  });
});

$("form-lompat").addEventListener("submit", (e) => {
  e.preventDefault();
  lompat(Number($("lompat").value));
  $("lompat").value = "";
});

$("tombol-pedoman").addEventListener("click", () => $("pedoman").showModal());
$("tutup-pedoman").addEventListener("click", () => $("pedoman").close());

// Peninjauan membawa anotator ke citra ragu yang pertama; sisanya dijangkau
// lewat peta dengan saringan "Ragu".
$("tombol-tinjau").addEventListener("click", () => {
  const pertama = daftar.findIndex((c) => {
    const j = jawaban.get(c.kode);
    return j && j.ragu;
  });
  if (pertama < 0) return;
  saringKini = "ragu";
  document.querySelectorAll(".saring button").forEach((b) => {
    b.setAttribute("aria-pressed", b.dataset.saring === "ragu" ? "true" : "false");
  });
  for (const tombol of sel.values()) saringSatu(tombol);
  lompat(pertama + 1);
});

document.addEventListener("keydown", (e) => {
  if (badan.dataset.layar !== "kerja") return;
  if (document.querySelector("dialog[open]")) return;
  if (e.target.tagName === "TEXTAREA" || e.target.tagName === "INPUT") {
    if (e.key === "Escape") e.target.blur();
    return;
  }
  const huruf = e.key.toLowerCase();
  if (TOMBOL_KE_KATEGORI[e.key]) { e.preventDefault(); jawab(TOMBOL_KE_KATEGORI[e.key]); }
  else if (huruf === "u") { e.preventDefault(); $("tombol-ragu").click(); }
  else if (huruf === "c") { e.preventDefault(); $("tombol-catatan").click(); }
  else if (huruf === "z") { e.preventDefault(); perbesar(); }
  else if (huruf === "p") { e.preventDefault(); bukaPeta(); }
  else if (e.key === "ArrowLeft") { e.preventDefault(); lompat(posisi); }
  else if (e.key === "ArrowRight") { e.preventDefault(); lompat(posisi + 2); }
  else if (e.key === "?") { e.preventDefault(); $("pedoman").showModal(); }
});

// Peringatan terakhir bila masih ada jawaban yang belum terkirim.
window.addEventListener("beforeunload", (e) => {
  if (menunggu > 0) { e.preventDefault(); e.returnValue = ""; }
});
