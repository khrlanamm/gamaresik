import 'package:flutter/material.dart';

class LearnTipsView extends StatelessWidget {
  const LearnTipsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belajar dan Tips')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Mengenal Kategori Sampah (UGM)',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTipCard(
            'Organik Terpilah',
            'Sampah organik adalah sampah yang berasal dari sisa makhluk hidup yang mudah terurai secara alami tanpa proses campur tangan manusia untuk dapat terurai.',
            'Contoh: Sisa makanan, dedaunan, ranting pohon, kulit buah, dll.',
            Colors.green.shade50,
            Colors.green,
          ),
          _buildTipCard(
            'Recycle Bersih',
            'Sampah anorganik yang masih memiliki nilai ekonomis dan dapat didaur ulang menjadi produk baru. Pastikan sampah dalam keadaan bersih dari sisa makanan atau cairan.',
            'Contoh: Botol plastik bersih, kertas, kardus, kaleng aluminium, botol kaca.',
            Colors.blue.shade50,
            Colors.blue,
          ),
          _buildTipCard(
            'Residu Terpilah',
            'Sampah residu adalah sampah yang sulit didaur ulang karena alasan teknis, ekonomis, atau sudah terkontaminasi limbah lain.',
            'Contoh: Tisu bekas, popok bayi, pembalut, puntung rokok, plastik pembungkus makanan yang kotor.',
            Colors.grey.shade100,
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String description, String examples, Color bgColor, Color accentColor) {
    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 8),
            Text(
              examples,
              style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
