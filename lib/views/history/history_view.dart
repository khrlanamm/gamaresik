import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/scan_record.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../widgets/gama_header.dart';

class HistoryView extends StatefulWidget {
  /// Injectable for tests; production builds create their own.
  final HistoryViewModel? viewModel;

  const HistoryView({super.key, this.viewModel});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late final HistoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? HistoryViewModel();
    _viewModel.fetchHistory();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        body: Column(
          children: [
            const GamaHeader(title: 'Riwayat Scan'),
            Expanded(
              child: Consumer<HistoryViewModel>(
                builder: (context, vm, _) {
                  if (vm.isLoading && vm.records.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return RefreshIndicator(
                    onRefresh: vm.fetchHistory,
                    child: _buildContent(vm),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(HistoryViewModel vm) {
    if (vm.errorMessage != null && vm.records.isEmpty) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        iconColor: AppTheme.red,
        title: 'Gagal memuat riwayat',
        message: vm.errorMessage,
        actionLabel: 'Coba Lagi',
        onAction: vm.fetchHistory,
      );
    }

    if (vm.records.isEmpty) {
      return const StateMessage(
        icon: Icons.history_rounded,
        title: 'Belum ada riwayat scan',
        message: 'Hasil klasifikasi sampah yang kamu scan akan muncul di sini.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      // One extra row for the "showing the latest N" footer when capped.
      itemCount: vm.records.length + (vm.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= vm.records.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Menampilkan ${HistoryViewModel.pageLimit} scan terbaru.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return _buildRecordCard(vm.records[index]);
      },
    );
  }

  Widget _buildRecordCard(ScanRecord record) {
    // Show what the user ultimately confirmed, not the superseded guess.
    final category = record.effectiveCategory;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: SizedBox(
              width: 60,
              height: 60,
              child: record.imageUrl != null
                  ? Image.network(
                      record.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppTheme.background,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: category.bgColor,
                        child: Icon(category.icon, color: category.color),
                      ),
                    )
                  : Container(
                      color: category.bgColor,
                      child: Icon(category.icon, color: category.color),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.classificationLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  formatScanDate(record.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      record.corrected
                          ? 'Dikoreksi'
                          : 'Keyakinan ${record.confidencePercentText}',
                      record.corrected ? AppTheme.greenPrimary : AppTheme.navyPrimary,
                    ),
                    if (record.usedFewShot) _chip('Few-shot', AppTheme.textMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
