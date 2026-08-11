import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/classification_result.dart';
import '../../models/waste_category.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_theme.dart';

enum _ResultPhase { processing, done, error }

class ResultView extends StatefulWidget {
  final String imagePath;
  const ResultView({super.key, required this.imagePath});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  final FirebaseService _firebaseService = FirebaseService();

  _ResultPhase _phase = _ResultPhase.processing;
  String? _errorMessage;
  ClassificationResult? _result;
  String? _storagePath;
  String? _imageUrl;
  bool _corrected = false;
  bool _isSubmittingCorrection = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _ResultPhase.processing;
      _errorMessage = null;
    });
    try {
      final uploaded = await _firebaseService.uploadScanImage(File(widget.imagePath));
      final result = await _firebaseService.classifyWaste(
        storagePath: uploaded.storagePath,
        imageUrl: uploaded.imageUrl,
      );
      if (!mounted) return;
      setState(() {
        _storagePath = uploaded.storagePath;
        _imageUrl = uploaded.imageUrl;
        _result = result;
        _phase = _ResultPhase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memproses gambar. Periksa koneksi internet Anda dan coba lagi.';
        _phase = _ResultPhase.error;
      });
    }
  }

  Future<void> _showCorrectionDialog() async {
    final result = _result;
    if (result == null || _storagePath == null || _imageUrl == null) return;

    final selected = await showModalBottomSheet<WasteCategory>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih kategori yang benar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyPrimary,
                  ),
                ),
              ),
            ),
            for (final category in WasteCategory.values)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: category.bgColor,
                  child: Icon(category.icon, color: category.color),
                ),
                title: Text(category.title),
                onTap: () => Navigator.pop(sheetContext, category),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _isSubmittingCorrection = true);
    try {
      await _firebaseService.submitCorrection(
        logId: result.logId,
        storagePath: _storagePath!,
        imageUrl: _imageUrl!,
        correctCategory: selected,
        originalPrediction: result.label,
        originalConfidence: result.confidenceScore,
      );
      if (!mounted) return;
      setState(() {
        _corrected = true;
        _isSubmittingCorrection = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terima kasih! Koreksi Anda membantu meningkatkan akurasi model.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingCorrection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim koreksi. Coba lagi.')),
      );
    }
  }

  void _finish() {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
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
                  'Hasil Scan',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _ResultPhase.processing:
        return _buildProcessing();
      case _ResultPhase.error:
        return _buildError();
      case _ResultPhase.done:
        return _buildResult(_result!);
    }
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.greenPrimary),
          SizedBox(height: 24),
          Text('Menganalisis gambar...', style: TextStyle(color: Colors.black54, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.greenPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali', style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(ClassificationResult result) {
    final category = result.category;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: category.bgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(category.icon, size: 64, color: category.color),
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
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text(
                category.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.navyPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildConfidenceBadge(result),
              if (result.reasoning != null && result.reasoning!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  result.reasoning!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: category.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: category.color, width: 2),
          ),
          child: Column(
            children: [
              const Text('Buang ke', style: TextStyle(color: Colors.black54, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                category.binLabel,
                style: TextStyle(color: category.color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoSection('Apa yang harus dilakukan?', category.description),
        const SizedBox(height: 24),
        _buildInfoSection('Item Serupa', category.examplesText, useCard: true),
        const SizedBox(height: 24),
        _buildInfoSection('Dampak Lingkungan', category.impact, isBlue: true),
        const SizedBox(height: 32),
        _buildCorrectionSection(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildConfidenceBadge(ClassificationResult result) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.navyPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Keyakinan ${result.confidencePercentText}',
            style: const TextStyle(
              color: AppTheme.navyPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.usedFewShot) ...[
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 6),
            const Text('Few-shot', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionSection() {
    if (_corrected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7EE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.greenPrimary, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Koreksi tersimpan, terima kasih!',
                style: TextStyle(color: AppTheme.navyPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: TextButton.icon(
        onPressed: _isSubmittingCorrection ? null : _showCorrectionDialog,
        icon: _isSubmittingCorrection
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.flag_outlined, size: 18),
        label: const Text('Hasil salah? Koreksi di sini'),
        style: TextButton.styleFrom(foregroundColor: Colors.black54),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, {bool useCard = false, bool isBlue = false}) {
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
                ? Border.all(color: Colors.grey.withValues(alpha: 0.1))
                : (isBlue ? Border.all(color: const Color(0xFFBFDBFE)) : null),
          ),
          child: Text(
            content,
            style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}
