import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();
    final user = viewModel.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 50) : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'Pengguna',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            
            _buildSection(
              'Misi Kami',
              'Memberdayakan individu untuk membuat pilihan berkelanjutan melalui pengelolaan sampah yang cerdas. Bersama-sama, kita dapat mengurangi sampah di tempat pembuangan dan melindungi planet kita untuk generasi mendatang.',
            ),
            
            const SizedBox(height: 24),
            
            _buildSection(
              'Klasifikasi Sampah UGM',
              'Klasifikasi 3 kategori sampah (Organik, Recycle Bersih, Residu) disesuaikan dengan standar pengelolaan sampah di Universitas Gadjah Mada.',
            ),
            
            const SizedBox(height: 32),
            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pengaturan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
                Icons.edit, 'Edit Profil', () => _showComingSoon(context)),
            _buildSettingItem(Icons.feedback_outlined, 'Kirim Masukan',
                () => _showComingSoon(context)),
            _buildSettingItem(
                Icons.info_outline, 'Tentang', () => _showAbout(context)),
            _buildSettingItem(Icons.logout, 'Keluar', () async {
              await viewModel.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ini akan segera hadir.')),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'GamaWaste',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/brands/logo_icon.png', width: 40, height: 40),
      ),
      applicationLegalese: '© ${DateTime.now().year} GamaWaste — Universitas Gadjah Mada',
      children: const [
        SizedBox(height: 16),
        Text(
          'GamaWaste membantu civitas UGM memilah sampah dengan cepat dan tepat sesuai standar pengelolaan sampah kampus.',
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.green),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : Colors.black87),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
