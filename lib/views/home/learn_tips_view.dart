import 'package:flutter/material.dart';
import '../../models/waste_category.dart';
import '../../utils/app_theme.dart';

class LearnTipsView extends StatelessWidget {
  const LearnTipsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header with Navy Gradient
          Container(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            decoration: const BoxDecoration(
              gradient: AppTheme.navyGradient,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Belajar & Tips',
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
                const Text(
                  'Pelajari cara memilah sampah dengan benar sesuai standar pengelolaan sampah Universitas Gadjah Mada.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Organik Terpilah
                _buildSection(
                  title: 'Organik Terpilah',
                  color: WasteCategory.organic.color,
                  icon: WasteCategory.organic.icon,
                  description:
                      'Sampah organik adalah jenis sampah yang berasal dari sisa makhluk hidup dan sangat mudah membusuk atau terurai secara alami oleh lingkungan. Sampah ini biasanya berasal dari sisa dapur atau sapuan halaman, yang nantinya akan diproses lebih lanjut untuk dijadikan pupuk kompos.',
                  examples: [
                    'Sisa makanan (nasi, lauk pauk, tulang)',
                    'Kulit buah dan potongan sayuran segar',
                    'Daun kering, rumput, dan ranting pohon',
                    'Tisu bekas pakai (bebas bahan kimia berbahaya)',
                    'Ampas kopi atau teh'
                  ],
                ),
                const SizedBox(height: 32),
                // Recycle Bersih Terpilah
                _buildSection(
                  title: 'Recycle Bersih Terpilah',
                  color: WasteCategory.recyclable.color,
                  icon: WasteCategory.recyclable.icon,
                  description:
                      'Sampah recycle adalah sampah berbahan non-organik yang masih memiliki nilai ekonomi dan wujudnya dapat didaur ulang menjadi produk baru. Syarat paling penting untuk kategori ini adalah wujud fisik sampah harus dalam keadaan bersih, kering, dan bebas dari kontaminasi sisa makanan maupun minyak.',
                  examples: [
                    'Botol dan gelas plastik minuman (kosong dan bersih)',
                    'Kardus kemasan paket atau kotak sepatu (kering)',
                    'Kertas HVS bekas tugas, koran, dan buku',
                    'Kaleng minuman alumunium (sudah dibilas)',
                    'Botol kaca (jika pecah, wajib dibungkus plastik tebal)'
                  ],
                ),
                const SizedBox(height: 32),
                // Residu Terpilah
                _buildSection(
                  title: 'Residu Terpilah',
                  color: WasteCategory.residual.color,
                  icon: WasteCategory.residual.icon,
                  description:
                      'Sampah residu adalah jenis sampah sisa yang sudah tidak memiliki nilai jual, sulit didaur ulang oleh pabrik, atau material recycle yang sudah terlanjur kotor dan berminyak. Kategori ini juga menjadi tempat pembuangan akhir untuk sampah-sampah kebersihan diri.',
                  examples: [
                    'Kemasan sachet (bungkus kopi instan, mi instan, sampo)',
                    'Kertas pembungkus nasi atau kardus makanan berminyak',
                    'Masker medis, pembalut, dan popok sekali pakai',
                    'Plastik kresek kotor dan bubblewrap',
                    'Styrofoam bekas pelindung barang atau makanan basah'
                  ],
                ),
                const SizedBox(height: 32),
                // Tips Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.navyGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tips Memilah Sampah',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTipItem(
                          'Bilas dan keringkan dahulu sampah recycle sebelum dibuang agar tidak membusuk.'),
                      _buildTipItem(
                          'Pindai (scan) sampah satu per satu agar sistem AI dapat mengenali dengan lebih akurat.'),
                      _buildTipItem(
                          'Pilih barang yang bisa dipakai berulang kali untuk menekan laju produksi sampah.'),
                      _buildTipItem(
                          'Ajak dan contohkan ke teman-temanmu cara memilah sampah yang benar.'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Bottom Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greenPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Mengerti!',
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

  Widget _buildSection({
    required String title,
    required Color color,
    required IconData icon,
    required String description,
    required List<String> examples,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.navyPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 32,
                  height: 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apa itu?',
                style: TextStyle(
                  color: AppTheme.navyPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Contoh:',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...examples.map((example) => Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      '• $example',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: AppTheme.lightGreen, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFA8D8C0),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
