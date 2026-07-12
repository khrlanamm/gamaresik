import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/scan_viewmodel.dart';
import '../../utils/app_theme.dart';
import '../result/result_view.dart';

class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  late ScanViewModel _viewModel;
  int _currentTipIndex = 0;
  Timer? _tipTimer;
  final List<String> _tips = [
    'Pastikan item terlihat jelas',
    'Item yang bersih lebih mudah dikenali',
    'Tahan kamera dengan stabil',
    'Pencahayaan yang baik membantu deteksi',
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = ScanViewModel();
    _viewModel.initializeCamera();
    _startTipRotation();
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<ScanViewModel>(
          builder: (context, vm, child) {
            if (!vm.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              children: [
                // Camera Preview
                Positioned.fill(
                  child: CameraPreview(vm.controller!),
                ),
                // Subtle Grid Overlay (Optional, but adds to the tech look)
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(),
                  ),
                ),
                // Top Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Posisikan item dalam bingkai',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer to balance back button
                      ],
                    ),
                  ),
                ),
                // Center Focus Frame
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.greenPrimary.withOpacity(0.5),
                          width: 2),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Stack(
                      children: [
                        // Corner Accents
                        _buildCorner(left: 0, top: 0, isTop: true, isLeft: true),
                        _buildCorner(right: 0, top: 0, isTop: true, isRight: true),
                        _buildCorner(left: 0, bottom: 0, isBottom: true, isLeft: true),
                        _buildCorner(right: 0, bottom: 0, isBottom: true, isRight: true),
                      ],
                    ),
                  ),
                ),
                // Bottom Tips Overlay
                Positioned(
                  bottom: 160,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.navyPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lightbulb_outline,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _tips[_currentTipIndex],
                              key: ValueKey<int>(_currentTipIndex),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Capture Button Area
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
                    color: const Color(0xFF001E32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final image = await vm.takePicture();
                          if (image != null && context.mounted) {
                            // Show results immediately or after simulation
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ResultView(imagePath: image.path),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text(
                          'Ambil Gambar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.greenPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCorner({
    double? left,
    double? top,
    double? right,
    double? bottom,
    bool isTop = false,
    bool isBottom = false,
    bool isLeft = false,
    bool isRight = false,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: AppTheme.greenPrimary, width: 4)
                : BorderSide.none,
            bottom: isBottom
                ? const BorderSide(color: AppTheme.greenPrimary, width: 4)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: AppTheme.greenPrimary, width: 4)
                : BorderSide.none,
            right: isRight
                ? const BorderSide(color: AppTheme.greenPrimary, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(32) : Radius.zero,
            topRight: isTop && isRight ? const Radius.circular(32) : Radius.zero,
            bottomLeft:
                isBottom && isLeft ? const Radius.circular(32) : Radius.zero,
            bottomRight:
                isBottom && isRight ? const Radius.circular(32) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
          Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
