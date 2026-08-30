import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/achievement.dart';
import '../../models/waste_category.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../history/history_view.dart';
import '../profile/profile_view.dart';
import '../scan/scan_view.dart';
import 'learn_tips_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomeViewModel>().refresh();
    });
  }

  Future<void> _openScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanView()),
    );
    // A scan writes its log and counters server-side, so pull the fresh
    // aggregates when the user lands back here.
    if (mounted) context.read<HomeViewModel>().refresh();
  }

  Future<void> _open(Widget view) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => view));
    if (mounted) context.read<HomeViewModel>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();
    final homeViewModel = context.watch<HomeViewModel>();
    final progress = homeViewModel.achievementProgress;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context, authViewModel, homeViewModel, progress),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<HomeViewModel>().refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  if (homeViewModel.errorMessage != null) ...[
                    _buildErrorBanner(homeViewModel.errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  _buildScanButton(),
                  const SizedBox(height: 28),
                  _buildAchievementCard(progress),
                  const SizedBox(height: 28),
                  _buildSectionHeader(),
                  const SizedBox(height: 8),
                  Text(
                    'Kenali 3 kategori sampah UGM beserta warna tempat sampahnya '
                    'sebelum memindai.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final category in WasteCategory.values) ...[
                    _buildCategoryCard(
                      category,
                      homeViewModel.categoryCounts[category] ?? 0,
                      homeViewModel.totalScanned,
                    ),
                    if (category != WasteCategory.values.last)
                      const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AuthViewModel authViewModel,
    HomeViewModel homeViewModel,
    AchievementProgress progress,
  ) {
    final photoURL = authViewModel.user?.photoURL;

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            child: Image.asset('assets/brands/logo_icon.png'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                overflow: TextOverflow.ellipsis,
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Gama',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Waste',
                                      style: TextStyle(
                                        color: AppTheme.lightGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                'Mari kelola sampah dengan bijak',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.onNavyMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _circleAction(
                        icon: Icons.history_rounded,
                        tooltip: 'Riwayat Scan',
                        onTap: () => _open(const HistoryView()),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Profil',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _open(const ProfileView()),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  photoURL != null ? NetworkImage(photoURL) : null,
                              // A failed avatar fetch should degrade to the
                              // placeholder, not throw into the framework.
                              onBackgroundImageError:
                                  photoURL != null ? (_, _) {} : null,
                              child: photoURL == null
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total',
                      homeViewModel.isLoading && homeViewModel.totalScanned == 0
                          ? '—'
                          : homeViewModel.totalScanned.toString(),
                      'item terpilah',
                      Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Target',
                      progress.next?.target.toString() ?? 'Selesai',
                      progress.next == null ? 'semua tercapai' : 'item berikutnya',
                      Icons.gps_fixed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildHeaderProgress(progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeaderProgress(AchievementProgress progress) {
    final label = progress.next == null
        ? 'Semua milestone tercapai'
        : 'Menuju ${progress.next!.target} item';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.onNavyMuted, fontSize: 12),
              ),
            ),
            Text(
              '${(progress.progress * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return InkWell(
      onTap: _openScan,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppTheme.greenGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Sampah',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Identifikasi & pilah sekarang',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(AchievementProgress progress) {
    final next = progress.next;
    final unlocked = progress.lastUnlocked;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  next?.icon ?? Icons.emoji_events_rounded,
                  color: AppTheme.yellow,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next?.title ?? 'Semua milestone tercapai',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? 'Luar biasa! Kamu menuntaskan seluruh milestone.'
                          : 'Kurang ${progress.remaining} scan lagi',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${progress.unlockedCount}/${Achievement.all.length}',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: AppTheme.borderSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.yellow),
            ),
          ),
          if (unlocked != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    size: 16, color: AppTheme.greenPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Terakhir diraih: ${unlocked.title}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Kategori Sampah UGM',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton.icon(
          onPressed: () => _open(const LearnTipsView()),
          icon: const Icon(Icons.menu_book_rounded, size: 16),
          label: const Text('Pelajari'),
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.navyPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String sublabel, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.onNavyMuted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            sublabel,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.onNavyMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(WasteCategory category, int count, int total) {
    final double percentage = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(category.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.classificationLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    // The bin colour is the actionable part of the education:
                    // it tells the user exactly where the item goes.
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: category.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            category.binLabel,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: category.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text('item', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: category.bgColor,
              valueColor: AlwaysStoppedAnimation<Color>(category.color),
            ),
          ),
        ],
      ),
    );
  }
}
