import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/achievement.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/gama_header.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    // Reuses the app-wide HomeViewModel rather than duplicating a second
    // stats fetcher, so Home and Profile can never disagree on the count.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeViewModel>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final homeViewModel = context.watch<HomeViewModel>();
    final user = authViewModel.user;
    final progress = homeViewModel.achievementProgress;

    return Scaffold(
      body: Column(
        children: [
          const GamaHeader(title: 'Profil'),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<HomeViewModel>().refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.borderSubtle,
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          // Without this a failed avatar fetch throws into the
                          // framework instead of just falling back.
                          onBackgroundImageError: user?.photoURL != null
                              ? (_, _) {}
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person,
                                  size: 44, color: AppTheme.textMuted)
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.displayName ?? 'Pengguna',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildSummary(progress),
                  const SizedBox(height: 28),
                  Text('Pencapaian', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Kumpulkan scan untuk membuka seluruh milestone.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  for (final achievement in Achievement.all) ...[
                    _buildAchievementTile(achievement, progress),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  Text('Tentang', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _buildSection(
                    'Misi Kami',
                    'Memberdayakan individu untuk membuat pilihan berkelanjutan melalui '
                        'pengelolaan sampah yang cerdas. Bersama-sama, kita dapat mengurangi '
                        'sampah di tempat pembuangan dan melindungi planet kita untuk '
                        'generasi mendatang.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    'Klasifikasi Sampah UGM',
                    'Klasifikasi 3 kategori sampah (Organik Terpilah, Recycle Bersih '
                        'Terpilah, Residu Terpilah) disesuaikan dengan standar pengelolaan '
                        'sampah di Universitas Gadjah Mada.',
                  ),
                  const SizedBox(height: 28),
                  Text('Pengaturan', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  _buildSettingItem(
                    Icons.info_outline,
                    'Tentang Aplikasi',
                    () => _showAbout(context),
                  ),
                  _buildSettingItem(
                    Icons.logout,
                    'Keluar',
                    () => _confirmSignOut(context, authViewModel),
                    isDestructive: true,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(AchievementProgress progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.navyGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryStat(progress.totalScans.toString(), 'Total Scan'),
              Container(width: 1, height: 40, color: Colors.white24),
              _summaryStat(
                '${progress.unlockedCount}/${Achievement.all.length}',
                'Milestone',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              progress.next == null
                  ? 'Semua milestone tercapai 🎉'
                  : 'Kurang ${progress.remaining} scan menuju "${progress.next!.title}"',
              style: const TextStyle(color: AppTheme.onNavyMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.lightGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppTheme.onNavyMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildAchievementTile(Achievement achievement, AchievementProgress progress) {
    final unlocked = achievement.isUnlockedAt(progress.totalScans);
    final color = unlocked ? AppTheme.greenPrimary : AppTheme.textMuted;
    final ratio = (progress.totalScans / achievement.target).clamp(0.0, 1.0);

    return Semantics(
      label: '${achievement.title}, '
          '${unlocked ? 'tercapai' : '${progress.totalScans} dari ${achievement.target} scan'}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked ? AppTheme.greenPrimary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: unlocked
                ? AppTheme.greenPrimary.withValues(alpha: 0.35)
                : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_outline_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (unlocked)
                        const Icon(Icons.check_circle,
                            color: AppTheme.greenPrimary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: AppTheme.borderSubtle,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    unlocked
                        ? 'Tercapai'
                        : '${progress.totalScans}/${achievement.target} scan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AuthViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk melakukan scan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final signedOut = await viewModel.signOut();
    if (!context.mounted) return;

    if (!signedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal keluar. Periksa koneksi lalu coba lagi.')),
      );
      return;
    }

    // AuthWrapper listens to authStateChanges and swaps in AuthView, so just
    // unwind back to the root instead of pushing a login route manually.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'GamaWaste',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Image.asset('assets/brands/logo_icon.png', width: 40, height: 40),
      ),
      applicationLegalese: '© 2026 GamaWaste — Universitas Gadjah Mada',
      children: const [
        SizedBox(height: 16),
        Text(
          'GamaWaste membantu civitas UGM memilah sampah dengan cepat dan tepat '
          'sesuai standar pengelolaan sampah kampus.',
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppTheme.red : AppTheme.navyPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: Icon(Icons.chevron_right, size: 20, color: color),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
