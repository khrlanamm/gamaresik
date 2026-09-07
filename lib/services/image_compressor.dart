import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

/// Menyusutkan hasil jepretan sebelum diunggah.
///
/// Kamera merekam pada `ResolutionPreset.high` (~720p) lalu menulis JPEG
/// berkualitas bawaan platform — pada perangkat uji hasilnya konsisten sekitar
/// 520 KB per foto. Sebagian besar byte itu tidak menambah informasi yang
/// dipakai model, sementara waktu unggahnya terasa langsung oleh pengguna di
/// jaringan kampus.
///
/// Yang dikurangi hanya kualitas encoding JPEG, bukan resolusinya: pada 720p
/// [_kQuality] tidak terlihat bedanya oleh mata maupun oleh model, sedangkan
/// ukurannya turun drastis. Diukur pada tangkapan nyata 720×1280 dari Storage,
/// 517 KB menjadi 188 KB — sekitar 64% lebih kecil.
///
/// [_kMinSide] hanya pengaman bila `ResolutionPreset` suatu saat dinaikkan.
/// Plugin menghitung `scale = max(1, min(srcW/minW, srcH/minH))`, jadi nilai
/// simetris berarti sisi terpendeklah yang menentukan, dan gambar tidak pernah
/// diperbesar. Pada 720p skalanya tepat 1.0, sehingga resolusi tidak berubah.
class ImageCompressor {
  const ImageCompressor._();

  /// Kualitas JPEG hasil encoding ulang.
  static const int _kQuality = 80;

  /// Sisi terpendek minimum yang dipertahankan.
  static const int _kMinSide = 720;

  /// Mengembalikan versi terkompresi dari [source].
  ///
  /// Mengembalikan [source] apa adanya bila kompresi gagal atau justru
  /// menghasilkan file yang lebih besar. Kegagalan di sini tidak boleh
  /// menggagalkan pemindaian — lebih baik mengunggah foto asli yang besar
  /// daripada menampilkan error kepada pengguna.
  static Future<File> compress(File source) async {
    try {
      final target = p.join(
        source.parent.path,
        '${p.basenameWithoutExtension(source.path)}_compressed.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        source.absolute.path,
        target,
        quality: _kQuality,
        minWidth: _kMinSide,
        minHeight: _kMinSide,
        format: CompressFormat.jpeg,
      );

      if (result == null) return source;

      final compressed = File(result.path);
      // Encoding ulang tidak selalu menang — foto yang sudah sangat termampat
      // bisa membengkak. Pakai yang lebih kecil.
      if (await compressed.length() >= await source.length()) {
        await _deleteQuietly(compressed);
        return source;
      }
      return compressed;
    } catch (_) {
      return source;
    }
  }

  /// Menghapus file sementara hasil kompresi; aman dipanggil untuk file asli
  /// (yang masih dipakai `ResultView` untuk pratinjau) karena hanya berkas
  /// bersufiks `_compressed` yang dihapus.
  static Future<void> disposeTemp(File file) async {
    if (p.basenameWithoutExtension(file.path).endsWith('_compressed')) {
      await _deleteQuietly(file);
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Berkas sementara; kegagalan menghapus bukan sesuatu yang perlu
      // disampaikan ke pengguna.
    }
  }
}
