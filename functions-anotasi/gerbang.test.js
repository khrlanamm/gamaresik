const test = require("node:test");
const assert = require("node:assert");
const g = require("./gerbang");

test("normalkan menyamakan huruf, spasi, dan tanda baca", () => {
  assert.strictEqual(g.normalkan(" anobidah01 "), "ANOBIDAH01");
  assert.strictEqual(g.normalkan("ano-bidah 01"), "ANOBIDAH01");
  assert.strictEqual(g.normalkan(null), "");
  assert.strictEqual(g.normalkan(undefined), "");
});

test("turunan cocok dengan nilai acuan pbkdf2-sha256", () => {
  // Nilai acuan dihitung dengan hashlib.pbkdf2_hmac("sha256", b"ANOBIDAH01",
  // bytes.fromhex("00112233445566778899aabbccddeeff"), 1000, 32).hex()
  const acuan = g.turunan("ANOBIDAH01", "00112233445566778899aabbccddeeff", 1000);
  assert.strictEqual(acuan.length, 64);
  assert.strictEqual(g.turunan("ANOBIDAH01", "00112233445566778899aabbccddeeff", 1000), acuan);
  assert.notStrictEqual(g.turunan("ANOBUDI02", "00112233445566778899aabbccddeeff", 1000), acuan);
});

test("samaAman menolak panjang berbeda tanpa melempar", () => {
  assert.ok(g.samaAman("abc", "abc"));
  assert.ok(!g.samaAman("abc", "abcd"));
  assert.ok(!g.samaAman("abc", "abd"));
});

test("gerbang terbuka selama belum terkunci", () => {
  assert.deepStrictEqual(g.periksa({}, 1000), { terkunci: false, detikTunggu: 0 });
  assert.deepStrictEqual(g.periksa({ terkunciHingga: 500 }, 1000),
      { terkunci: false, detikTunggu: 0 });
});

test("gerbang tertutup dan melaporkan sisa waktu", () => {
  const hasil = g.periksa({ terkunciHingga: 61_000 }, 1_000);
  assert.strictEqual(hasil.terkunci, true);
  assert.strictEqual(hasil.detikTunggu, 60);
});

test("kegagalan menumpuk lalu mengunci pada percobaan keenam", () => {
  let jejak = {};
  const t = 1_000_000;
  for (let i = 1; i < g.GAGAL_MAKS; i++) {
    jejak = g.gagalSekali(jejak, t + i);
    assert.strictEqual(jejak.gagal, i);
    assert.strictEqual(jejak.terkunciHingga, null, `percobaan ${i} tidak boleh mengunci`);
  }
  jejak = g.gagalSekali(jejak, t + g.GAGAL_MAKS);
  assert.strictEqual(jejak.gagal, g.GAGAL_MAKS);
  assert.strictEqual(jejak.terkunciHingga, t + g.GAGAL_MAKS + g.KUNCI_AWAL_MS);
});

test("kunci berlipat dan berhenti pada batas atas", () => {
  let jejak = {};
  const t = 1_000_000;
  for (let i = 1; i <= 12; i++) jejak = g.gagalSekali(jejak, t + i);
  assert.ok(jejak.terkunciHingga - (t + 12) <= g.KUNCI_MAKS_MS);
  assert.strictEqual(jejak.terkunciHingga - (t + 12), g.KUNCI_MAKS_MS);
});

test("kegagalan lama dilupakan sesudah jendela lewat", () => {
  const t = 1_000_000;
  const lama = { gagal: 5, jendelaSejak: t, terkunciHingga: null };
  const baru = g.gagalSekali(lama, t + g.JENDELA_MS + 1);
  assert.strictEqual(baru.gagal, 1);
  assert.strictEqual(baru.terkunciHingga, null);
});

test("keberhasilan mengosongkan hitungan", () => {
  assert.strictEqual(g.BERHASIL.gagal, 0);
  assert.strictEqual(g.BERHASIL.terkunciHingga, null);
});

test("gerbang global menahan jauh lebih banyak kegagalan daripada satu alamat", () => {
  let jejak = { gagal: 0, jendelaSejak: 0, terkunciHingga: 0 };
  const t = 1_700_000_000_000;
  for (let i = 0; i < g.GAGAL_MAKS; i++) {
    jejak = g.gagalSekali(jejak, t + i, g.GAGAL_GLOBAL);
  }
  assert.equal(jejak.terkunciHingga, null,
      "enam salah ketik tidak boleh mengunci seluruh situs");

  for (let i = g.GAGAL_MAKS; i < g.GAGAL_GLOBAL; i++) {
    jejak = g.gagalSekali(jejak, t + i, g.GAGAL_GLOBAL);
  }
  assert.ok(jejak.terkunciHingga > t, "empat puluh kegagalan mengunci");
});
