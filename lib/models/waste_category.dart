import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// The three waste categories used by UGM's waste management standard.
///
/// [id] is the only value ever written to or read from Firestore — every
/// other getter is presentation-only and safe to restyle freely without
/// breaking previously saved classifications.
enum WasteCategory {
  organic,
  recyclable,
  residual;

  static WasteCategory fromId(String? id) {
    return WasteCategory.values.firstWhere(
      (category) => category.id == id,
      orElse: () => WasteCategory.residual,
    );
  }

  /// Maps a raw Gemini classification label (see [classificationLabel]) back
  /// to a [WasteCategory]. Falls back to [residual] for anything unexpected
  /// so a model/prompt drift never crashes the UI.
  static WasteCategory fromClassificationLabel(String? label) {
    return WasteCategory.values.firstWhere(
      (category) => category.classificationLabel == label,
      orElse: () => WasteCategory.residual,
    );
  }

  String get id {
    switch (this) {
      case WasteCategory.organic:
        return 'organic';
      case WasteCategory.recyclable:
        return 'recyclable';
      case WasteCategory.residual:
        return 'residual';
    }
  }

  /// The exact label string the classifyWaste Cloud Function's Gemini prompt
  /// is instructed to return.
  ///
  /// Fixed by Tabel 4.1 of the thesis (Blok A) — keep in sync with
  /// CATEGORY_TO_ID in functions/classifier.js; a test asserts the two agree.
  String get classificationLabel {
    switch (this) {
      case WasteCategory.organic:
        return 'organik';
      case WasteCategory.recyclable:
        return 'recycle';
      case WasteCategory.residual:
        return 'residu';
    }
  }

  /// The category's official name in the UGM Rector's circular.
  ///
  /// Kept apart from [classificationLabel]: that one is the model's output
  /// vocabulary and is deliberately terse, while this is what people read on
  /// screen and on the bins themselves.
  String get officialName {
    switch (this) {
      case WasteCategory.organic:
        return 'Organik Terpilah';
      case WasteCategory.recyclable:
        return 'Recycle Bersih Terpilah';
      case WasteCategory.residual:
        return 'Residu Terpilah';
    }
  }

  String get title {
    switch (this) {
      case WasteCategory.organic:
        return 'Sampah Organik';
      case WasteCategory.recyclable:
        return 'Sampah Recycle Bersih';
      case WasteCategory.residual:
        return 'Sampah Residu';
    }
  }

  String get binLabel {
    switch (this) {
      case WasteCategory.organic:
        return 'Tempat Sampah Hijau';
      case WasteCategory.recyclable:
        return 'Tempat Sampah Kuning';
      case WasteCategory.residual:
        return 'Tempat Sampah Merah';
    }
  }

  IconData get icon {
    switch (this) {
      case WasteCategory.organic:
        return Icons.eco_rounded;
      case WasteCategory.recyclable:
        return Icons.recycling_rounded;
      case WasteCategory.residual:
        return Icons.delete_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case WasteCategory.organic:
        return AppTheme.greenPrimary;
      case WasteCategory.recyclable:
        return AppTheme.yellow;
      case WasteCategory.residual:
        return AppTheme.red;
    }
  }

  /// Contrast-safe variant of [color] for text on light backgrounds.
  ///
  /// The raw category colours are tuned for filled chips and icons; used as
  /// text on white they fail WCAG AA badly (the yellow sits near 1.9:1).
  /// These darkened variants clear 4.5:1.
  Color get textColor {
    switch (this) {
      case WasteCategory.organic:
        return const Color(0xFF0A7C39);
      case WasteCategory.recyclable:
        return const Color(0xFF9A6B04);
      case WasteCategory.residual:
        return const Color(0xFFC62828);
    }
  }

  Color get bgColor {
    switch (this) {
      case WasteCategory.organic:
        return const Color(0xFFE6F7EE);
      case WasteCategory.recyclable:
        return const Color(0xFFFFF9C4);
      case WasteCategory.residual:
        return const Color(0xFFFFEBEE);
    }
  }

  /// Longer explanation used on the onboarding cards.
  String get onboardingDescription {
    switch (this) {
      case WasteCategory.organic:
        return 'Material yang dapat terurai secara alami seperti sisa makanan, '
            'kulit buah, daun kering, dan tisu. Diolah lebih lanjut menjadi kompos.';
      case WasteCategory.recyclable:
        return 'Material non-organik bernilai daur ulang seperti botol plastik, '
            'kertas, dan kardus — wajib dalam kondisi bersih dan kering.';
      case WasteCategory.residual:
        return 'Material sisa yang tidak dapat didaur ulang seperti kemasan '
            'sachet, bungkus kotor berminyak, styrofoam, dan masker.';
    }
  }

  String get description {
    switch (this) {
      case WasteCategory.organic:
        return 'Item ini dapat terurai secara alami. Item ini harus dibuang ke tempat sampah organik untuk dijadikan kompos.';
      case WasteCategory.recyclable:
        return 'Item ini dapat didaur ulang menjadi produk baru. Pastikan bersih sebelum dimasukkan ke tempat sampah recycle.';
      case WasteCategory.residual:
        return 'Item ini tidak dapat didaur ulang atau dikompos. Item ini harus dibuang ke tempat sampah umum.';
    }
  }

  String get impact {
    switch (this) {
      case WasteCategory.organic:
        return 'Mengompos sampah organik mengurangi emisi metana dari tempat pembuangan dan menciptakan tanah yang kaya nutrisi.';
      case WasteCategory.recyclable:
        return 'Daur ulang menghemat sumber daya alam dan mengurangi konsumsi energi dalam manufaktur.';
      case WasteCategory.residual:
        return 'Minimalkan sampah residu dengan memilih alternatif yang dapat digunakan kembali dan didaur ulang.';
    }
  }

  List<String> get sampleItems {
    switch (this) {
      case WasteCategory.organic:
        return ['Sisa makanan', 'Kulit buah', 'Ranting/daun', 'Tisu', 'Ampas kopi'];
      case WasteCategory.recyclable:
        return ['Botol plastik', 'Kertas HVS', 'Kardus', 'Kaleng logam', 'Botol kaca'];
      case WasteCategory.residual:
        return ['Kemasan sachet', 'Bungkus berminyak', 'Masker', 'Popok', 'Styrofoam'];
    }
  }

  String get examplesText => sampleItems.join(', ');
}
