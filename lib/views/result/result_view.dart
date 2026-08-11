import 'package:flutter/material.dart';
import '../../models/waste_category.dart';
import '../../services/firebase_service.dart';
import '../../utils/app_theme.dart';

class ResultView extends StatefulWidget {
  final String imagePath;
  const ResultView({super.key, required this.imagePath});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isSaving = false;
  late final WasteCategory _category;
  late final String _itemName;

  @override
  void initState() {
    super.initState();
    _category = _mockClassify(widget.imagePath);
    _itemName = _category.sampleItems.first;
  }

  // TODO: replace with a real on-device/ML classification of the captured
  // photo. Until that's wired up, this derives a deterministic category from
  // the image path so results vary run-to-run instead of always showing the
  // same category.
  WasteCategory _mockClassify(String imagePath) {
    final hash = imagePath.hashCode.abs();
    return WasteCategory.values[hash % WasteCategory.values.length];
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    try {
      await _firebaseService.saveClassification(_category, imagePath: widget.imagePath);
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan hasil. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;

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
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                          color: category.bgColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
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
                      Text(
                        _itemName,
                        style: const TextStyle(
                          color: AppTheme.navyPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.title,
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
                    color: category.bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: category.color, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Buang ke',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.binLabel,
                        style: TextStyle(
                          color: category.color,
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
                  category.description,
                ),
                const SizedBox(height: 24),
                // Examples
                _buildInfoSection(
                  'Item Serupa',
                  category.examplesText,
                  useCard: true,
                ),
                const SizedBox(height: 24),
                // Environmental Impact
                _buildInfoSection(
                  'Dampak Lingkungan',
                  category.impact,
                  isBlue: true,
                ),
                const SizedBox(height: 40),
                // Finish Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.greenPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.greenPrimary.withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
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
                ? Border.all(color: Colors.grey.withValues(alpha: 0.1))
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
}
