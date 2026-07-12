import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_theme.dart';

class ResultView extends StatelessWidget {
  final String imagePath;
  const ResultView({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    // Mock result for now, could be passed from ScanViewModel
    final resultType = "recyclable"; // organic, recyclable, residual
    final info = _getWasteInfo(resultType);

    final FirebaseService firebaseService = FirebaseService();

    void saveResult() async {
      await firebaseService.saveClassification({
        'result': info.title,
        'imagePath': imagePath,
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header with Navy Gradient
          Container(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(
              gradient: AppTheme.navyGradient,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Hasil Scan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // Result Icon
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          color: info.bgColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Icon(info.icon, size: 64, color: info.color),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.greenPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Item Name
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Botol Plastik', // Mock item name
                        style: TextStyle(
                          color: AppTheme.navyPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.title,
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Bin Color Recommendation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: info.bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: info.color, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Buang ke',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.binColor,
                        style: TextStyle(
                          color: info.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Description
                _buildInfoSection(
                  'Apa yang harus dilakukan?',
                  info.description,
                ),
                const SizedBox(height: 24),
                // Examples
                _buildInfoSection(
                  'Item Serupa',
                  info.examples,
                  useCard: true,
                ),
                const SizedBox(height: 24),
                // Environmental Impact
                _buildInfoSection(
                  'Dampak Lingkungan',
                  info.impact,
                  isBlue: true,
                ),
                const SizedBox(height: 40),
                // Finish Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      saveResult();
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greenPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Kembali ke Beranda',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content,
      {bool useCard = false, bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.navyPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isBlue ? const Color(0xFFEEF5FB) : (useCard ? Colors.white : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: useCard
                ? Border.all(color: Colors.grey.withOpacity(0.1))
                : (isBlue ? Border.all(color: const Color(0xFFBFDBFE)) : null),
          ),
          child: Text(
            content,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  _WasteTypeInfo _getWasteInfo(String type) {
    switch (type) {
      case 'organic':
        return _WasteTypeInfo(
          icon: Icons.eco_rounded,
          color: AppTheme.greenPrimary,
          bgColor: const Color(0xFFE6F7EE),
          title: 'Sampah Organik',
          binColor: 'Tempat Sampah Hijau',
          description:
              'Item ini dapat terurai secara alami. Item ini harus dibuang ke tempat sampah organik untuk dijadikan kompos.',
          examples: 'Sisa makanan, kulit buah, sayuran, daun kering, ampas kopi',
          impact:
              'Mengompos sampah organik mengurangi emisi metana dari tempat pembuangan dan menciptakan tanah yang kaya nutrisi.',
        );
      case 'recyclable':
        return _WasteTypeInfo(
          icon: Icons.recycling_rounded,
          color: AppTheme.yellow,
          bgColor: const Color(0xFFFFF9C4),
          title: 'Sampah Recycle Bersih',
          binColor: 'Tempat Sampah Kuning',
          description:
              'Item ini dapat didaur ulang menjadi produk baru. Pastikan bersih sebelum dimasukkan ke tempat sampah recycle.',
          examples: 'Botol plastik, kertas, kardus, kaleng logam, botol kaca',
          impact:
              'Daur ulang menghemat sumber daya alam dan mengurangi konsumsi energi dalam manufaktur.',
        );
      case 'residual':
      default:
        return _WasteTypeInfo(
          icon: Icons.delete_outline_rounded,
          color: AppTheme.red,
          bgColor: const Color(0xFFFFEBEE),
          title: 'Sampah Residu',
          binColor: 'Tempat Sampah Merah',
          description:
              'Item ini tidak dapat didaur ulang atau dikompos. Item ini harus dibuang ke tempat sampah umum.',
          examples: 'Kemasan sachet, bungkus berminyak, masker, popok, styrofoam',
          impact:
              'Minimalkan sampah residu dengan memilih alternatif yang dapat digunakan kembali dan didaur ulang.',
        );
    }
  }
}

class _WasteTypeInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String title;
  final String binColor;
  final String description;
  final String examples;
  final String impact;

  _WasteTypeInfo({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.title,
    required this.binColor,
    required this.description,
    required this.examples,
    required this.impact,
  });
}
