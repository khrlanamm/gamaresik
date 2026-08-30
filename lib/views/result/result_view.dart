import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/classification_result.dart';
import '../../models/waste_category.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/gama_header.dart';

enum _Phase { uploading, classifying, done, error }

class ResultView extends StatefulWidget {
  final String imagePath;
  const ResultView({super.key, required this.imagePath});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  final FirebaseService _firebaseService = FirebaseService();

  /// Generated once per capture and reused on every retry, so the backend can
  /// recognise a repeat attempt and neither re-bill inference nor double-count
  /// the scan.
  late final String _scanId;
  late final File _imageFile;

  _Phase _phase = _Phase.uploading;
  String? _errorMessage;
  ClassificationResult? _result;
  bool _corrected = false;
  WasteCategory? _correctedTo;
  bool _isSubmittingCorrection = false;

  @override
  void initState() {
    super.initState();
    _scanId = _firebaseService.newScanRequestId();
    _imageFile = File(widget.imagePath);
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.uploading;
      _errorMessage = null;
    });

    try {
      final uploaded = await _firebaseService.uploadScanImage(
        _imageFile,
        scanId: _scanId,
      );

      if (!mounted) return;
      setState(() => _phase = _Phase.classifying);

      final result = await _firebaseService.classifyWaste(
        storagePath: uploaded.storagePath,
        imageUrl: uploaded.imageUrl,
        scanId: _scanId,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _corrected = false;
        _correctedTo = null;
        _phase = _Phase.done;
      });
    } on ScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _phase = _Phase.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memproses gambar. Periksa koneksi internet Anda lalu coba lagi.';
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _reportIncorrect() async {
    final result = _result;
    if (result == null || _isSubmittingCorrection) return;

    final currentCategory = _correctedTo ?? result.category;

    final selected = await showModalBottomSheet<WasteCategory>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                'Pilih kategori yang benar',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Koreksi Anda dipakai sebagai contoh tervalidasi untuk meningkatkan akurasi model.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
            for (final category in WasteCategory.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.bgColor,
                  child: Icon(category.icon, color: category.color),
                ),
                title: Text(category.title),
                subtitle: Text(
                  category.binLabel,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                trailing: category == currentCategory
                    ? const Icon(Icons.check_circle, color: AppTheme.greenPrimary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, category),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _isSubmittingCorrection = true);
    try {
      await _firebaseService.submitCorrection(
        logId: result.logId,
        correctCategory: selected,
      );
      if (!mounted) return;
      setState(() {
        _corrected = true;
        _correctedTo = selected;
        _isSubmittingCorrection = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih! Koreksi Anda membantu meningkatkan akurasi model.'),
        ),
      );
    } on ScanException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingCorrection = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingCorrection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim koreksi. Coba lagi.')),
      );
    }
  }

  void _finish() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GamaHeader(title: 'Hasil Scan'),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.uploading:
      case _Phase.classifying:
        return _buildProcessing();
      case _Phase.error:
        return _buildError();
      case _Phase.done:
        return _buildResult(_result!);
    }
  }

  Widget _buildCapturedImage({double height = 220}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Image.file(
        _imageFile,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          color: AppTheme.borderSubtle,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined,
              color: AppTheme.textMuted, size: 40),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    final isUploading = _phase == _Phase.uploading;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCapturedImage(),
        const SizedBox(height: 32),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 20),
        Text(
          isUploading ? 'Mengunggah gambar...' : 'Menganalisis dengan AI...',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isUploading
              ? 'Menyimpan foto Anda dengan aman.'
              : 'Menentukan kategori sampah dan tingkat keyakinan.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCapturedImage(height: 160),
        const SizedBox(height: 24),
        const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 56),
        const SizedBox(height: 16),
        Text(
          'Gagal menganalisis',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Terjadi kesalahan.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _run,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          label: const Text('Coba Lagi'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Ambil Foto Ulang'),
        ),
      ],
    );
  }

  Widget _buildResult(ClassificationResult result) {
    // A human correction supersedes the model's guess everywhere in this view.
    final category = _correctedTo ?? result.category;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCapturedImage(),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: category.bgColor, shape: BoxShape.circle),
                child: Icon(category.icon, size: 48, color: category.color),
              ),
              const SizedBox(height: 16),
              Text(
                category.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              if (_corrected) _buildCorrectedBadge() else _buildConfidenceBadge(result),
              if (!_corrected &&
                  result.reasoning != null &&
                  result.reasoning!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  result.reasoning!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        if (!_corrected && result.isLowConfidence) ...[
          const SizedBox(height: 20),
          _buildLowConfidenceWarning(result),
        ],
        const SizedBox(height: 24),
        _buildBinCard(category),
        const SizedBox(height: 24),
        _buildInfoSection('Apa yang harus dilakukan?', category.description),
        const SizedBox(height: 20),
        _buildInfoSection('Item Serupa', category.examplesText, useCard: true),
        const SizedBox(height: 20),
        _buildInfoSection('Dampak Lingkungan', category.impact, isBlue: true),
        if (!_corrected) ...[
          const SizedBox(height: 20),
          _buildMethodNote(result),
        ],
        const SizedBox(height: 28),
        _buildFeedbackSection(),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _finish, child: const Text('Kembali ke Beranda')),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The fail-safe from section 4.4.3.
  ///
  /// When the score is still under the threshold after a selective few-shot
  /// re-inference, the prediction is shown anyway — refusing to answer helps
  /// nobody standing in front of three bins — but it is labelled as uncertain
  /// and the user is pushed towards the correction button, which is also what
  /// grows the validated example pool.
  Widget _buildLowConfidenceWarning(ClassificationResult result) {
    final threshold = result.confidenceThreshold;
    final thresholdText =
        threshold == null ? '' : ' (ambang batas ${formatConfidence(threshold)})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFE0A32A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 22, color: Color(0xFF9A6B04)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediksi Tingkat Keyakinan Rendah',
                  style: TextStyle(
                    color: Color(0xFF7A5503),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keyakinan model hanya ${result.confidencePercentText}$thresholdText. '
                  'Mohon periksa kembali sendiri sebelum membuang, dan laporkan '
                  'lewat tombol di bawah jika kategorinya keliru.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7A5503),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBinCard(WasteCategory category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: category.bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: category.color, width: 2),
      ),
      child: Column(
        children: [
          Text('Buang ke', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  category.binLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: category.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(ClassificationResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.navyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insights_rounded, size: 16, color: AppTheme.navyPrimary),
          const SizedBox(width: 6),
          Text(
            'Keyakinan ${result.confidencePercentText}',
            style: const TextStyle(
              color: AppTheme.navyPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.usedFewShot) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 12, color: AppTheme.borderSubtle),
            const SizedBox(width: 8),
            const Text(
              'Few-shot',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.greenPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 16, color: AppTheme.greenPrimary),
          SizedBox(width: 6),
          Text(
            'Dikoreksi oleh Anda',
            style: TextStyle(
              color: AppTheme.greenPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Surfaces which strategy actually produced the answer. Useful for the
  /// thesis demo: in selective mode it shows the escalation actually happening.
  Widget _buildMethodNote(ClassificationResult result) {
    final buffer = StringBuffer('Mode klasifikasi: ${result.mode}');
    if (result.escalated && result.zeroShotConfidence != null) {
      final zero = (result.zeroShotConfidence! * 100).round();
      buffer.write(
        result.usedFewShot
            ? '. Keyakinan zero-shot $zero% berada di bawah ambang batas, '
                'sehingga sistem menjalankan ulang klasifikasi dengan '
                '${result.fewShotExampleCount} contoh tervalidasi.'
            : '. Keyakinan zero-shot $zero% berada di bawah ambang batas, '
                'namun belum ada contoh tervalidasi untuk dipakai.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(buffer.toString(), style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_corrected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.greenPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.greenPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Koreksi tersimpan sebagai contoh tervalidasi. Terima kasih!',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: _isSubmittingCorrection ? null : _reportIncorrect,
              child: const Text('Ubah'),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isSubmittingCorrection ? null : _reportIncorrect,
      icon: _isSubmittingCorrection
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Laporan Hasil Tidak Tepat'),
    );
  }

  Widget _buildInfoSection(String title, String content,
      {bool useCard = false, bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isBlue
                ? const Color(0xFFEEF5FB)
                : (useCard ? Colors.white : Colors.transparent),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: useCard
                ? Border.all(color: AppTheme.borderSubtle)
                : (isBlue ? Border.all(color: const Color(0xFFBFDBFE)) : null),
          ),
          child: Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
