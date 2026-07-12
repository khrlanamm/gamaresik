import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../auth/auth_view.dart';
import '../scan/scan_view.dart';
import '../profile/profile_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final isLoggedIn = authViewModel.user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GamaWaste'),
        actions: [
          if (isLoggedIn)
            IconButton(
              icon: CircleAvatar(
                backgroundImage: authViewModel.user?.photoURL != null
                    ? NetworkImage(authViewModel.user!.photoURL!)
                    : null,
                child: authViewModel.user?.photoURL == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileView()),
                );
              },
            )
          else
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthView()),
                );
              },
              child: const Text('Login'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Waste Categories (UGM)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCategoryCard(
              context,
              'Organik Terpilah',
              'Sisa makanan, dedaunan, dan bahan organik lainnya.',
              Colors.green.shade100,
              Icons.eco,
            ),
            _buildCategoryCard(
              context,
              'Recycle Bersih Terpilah',
              'Plastik, kertas, botol, dan material daur ulang yang bersih.',
              Colors.blue.shade100,
              Icons.recycling,
            ),
            _buildCategoryCard(
              context,
              'Residu Terpilah',
              'Sampah yang tidak dapat didaur ulang maupun dikompos.',
              Colors.grey.shade300,
              Icons.delete_outline,
            ),
            const SizedBox(height: 32),
            if (!isLoggedIn)
              Center(
                child: Column(
                  children: [
                    const Text('Want to help classify?'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AuthView()),
                        );
                      },
                      child: const Text('Login to Scan'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScanView()),
                );
              },
              label: const Text('Scan Trash'),
              icon: const Icon(Icons.camera_alt),
            )
          : null,
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String description, Color color, IconData icon) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.black54),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
