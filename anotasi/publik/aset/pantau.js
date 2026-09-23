// Halaman peneliti. Menampilkan kemajuan kedua anotator dan tidak pernah
// menampilkan label, sebab dokumen jawaban memang tertutup bagi peneliti
// selama anotasi berlangsung.
import {
  collection, onSnapshot,
} from "https://www.gstatic.com/firebasejs/12.3.0/firebase-firestore.js";
import {
  db, masuk, keluar, pantauMasuk, klaim, pesanGalat, waktuRelatif,
} from "./bersama.js";
import { TOTAL_CITRA } from "./firebase-konfig.js";

const $ = (id) => document.getElementById(id);
const badan = document.body;
let berhenti = null;

$("form-masuk").addEventListener("submit", async (e) => {
  e.preventDefault();
  const tombol = $("tombol-masuk");
  tombol.disabled = true;
  $("galat-masuk").textContent = "";
  try {
    const hasil = await masuk($("kode").value);
    if (hasil.peran !== "peneliti") {
      await keluar();
      $("galat-masuk").textContent = "Kode ini untuk anotasi, bukan pemantauan.";
      tombol.disabled = false;
    }
  } catch (galat) {
    $("galat-masuk").textContent = pesanGalat(galat);
    tombol.disabled = false;
  }
});

$("tombol-keluar").addEventListener("click", async () => {
  if (berhenti) { berhenti(); berhenti = null; }
  await keluar();
  location.reload();
});

pantauMasuk(async (pengguna) => {
  if (!pengguna) { badan.dataset.layar = "masuk"; return; }
  const { peran } = await klaim(pengguna);
  if (peran !== "peneliti") { location.href = "/"; return; }
  badan.dataset.layar = "pantau";
  pantau();
});

function pantau() {
  if (berhenti) return;
  berhenti = onSnapshot(collection(db, "anotasi_kemajuan"), (cuplikan) => {
    const baris = cuplikan.docs
        .map((d) => ({ id: d.id, ...d.data() }))
        .sort((a, b) => a.id.localeCompare(b.id));
    gambar(baris);
  }, () => {
    $("kartu-kartu").innerHTML =
        "<div class=\"kartu\"><p class=\"galat\">Gagal membaca kemajuan.</p></div>";
  });
}

function gambar(baris) {
  const wadah = $("kartu-kartu");
  if (!baris.length) {
    wadah.innerHTML = "<div class=\"kartu\"><h2>Belum ada kemajuan</h2>" +
        "<p class=\"catatan-kecil\">Kartu muncul begitu seorang anotator " +
        "menilai citra pertamanya.</p></div>";
    return;
  }
  wadah.innerHTML = "";
  for (const b of baris) wadah.appendChild(kartu(b));
}

function kartu(b) {
  const selesai = b.jumlahSelesai || 0;
  const persen = Math.min(100, (selesai / TOTAL_CITRA) * 100);
  const rerata = selesai ? (b.detikAktif || 0) / selesai : 0;
  const sisa = Math.max(0, TOTAL_CITRA - selesai);

  const el = document.createElement("div");
  el.className = "kartu";
  el.append(
      tandaLencana(b.selesai === true || selesai >= TOTAL_CITRA),
      unsur("h2", "", b.nama || b.id),
      unsur("span", "id", b.id),
      bilah(persen),
      rinci([
        [selesai + " / " + TOTAL_CITRA, "citra dinilai"],
        [persen.toFixed(1) + "%", "kemajuan"],
        [String(b.jumlahRagu || 0), "ditandai ragu"],
        [String(b.jumlahCatatan || 0), "diberi catatan"],
        [rerata ? rerata.toFixed(1) + " dtk" : "—", "rerata per citra"],
        [durasi(b.detikAktif || 0), "waktu aktif"],
        [sisa ? durasi(Math.round(sisa * rerata)) : "selesai", "perkiraan sisa"],
        [waktuRelatif(tanggal(b.terakhirAktif)), "terakhir aktif"],
      ]),
  );
  return el;
}

function tandaLencana(usai) {
  const el = unsur("span", "lencana", usai ? "selesai" : "berjalan");
  el.dataset.selesai = usai ? "ya" : "tidak";
  return el;
}

function unsur(nama, kelas, teks) {
  const el = document.createElement(nama);
  if (kelas) el.className = kelas;
  el.textContent = teks;
  return el;
}

function bilah(persen) {
  const luar = document.createElement("span");
  luar.className = "bilah";
  const dalam = document.createElement("span");
  dalam.style.width = persen + "%";
  luar.appendChild(dalam);
  return luar;
}

function rinci(pasangan) {
  const wadah = document.createElement("div");
  wadah.className = "rinci";
  for (const [nilai, label] of pasangan) {
    const kotak = document.createElement("div");
    kotak.append(unsur("span", "nilai", nilai), unsur("span", "label", label));
    wadah.appendChild(kotak);
  }
  return wadah;
}

/** Ubah Timestamp Firestore menjadi Date, dengan aman bila medannya kosong. */
function tanggal(nilai) {
  return nilai && typeof nilai.toDate === "function" ? nilai.toDate() : null;
}

/** Lama waktu dalam bahasa Indonesia, dari detik. */
function durasi(detik) {
  if (!detik) return "—";
  const jam = Math.floor(detik / 3600);
  const menit = Math.round((detik % 3600) / 60);
  if (jam) return jam + " jam " + menit + " menit";
  if (menit) return menit + " menit";
  return detik + " detik";
}
