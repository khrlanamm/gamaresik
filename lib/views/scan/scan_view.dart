import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/scan_viewmodel.dart';
import '../result/result_view.dart';

class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> with WidgetsBindingObserver {
  late final ScanViewModel _viewModel;
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  static const List<String> _tips = [
    'Pastikan item terlihat jelas',
    'Item yang bersih lebih mudah dikenali',
    'Pindai satu item dalam satu foto',
    'Pencahayaan yang baik membantu deteksi',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel = ScanViewModel();
    _viewModel.initializeCamera();
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _currentTipIndex = (_currentTipIndex + 1) % _tips.length);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tipTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hand the camera back while backgrounded and re-acquire on resume;
    // holding it across a background/foreground cycle throws on Android.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _viewModel.releaseForBackground();
    } else if (state == AppLifecycleState.resumed) {
      _viewModel.initializeCamera();
    }
  }

  Future<void> _capture(ScanViewModel vm) async {
    final image = await vm.takePicture();
    if (image == null || !mounted) return;

    // pushReplacement: the capture screen should not sit under the result, so
    // backing out of the result lands on Home.
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultView(imagePath: image.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<ScanViewModel>(
          builder: (context, vm, child) {
            if (vm.errorMessage != null) return _buildErrorState(context, vm);
            if (!vm.isInitialized || vm.controller == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            return _buildCamera(context, vm);
          },
        ),
      ),
    );
  }

  Widget _buildCamera(BuildContext context, ScanViewModel vm) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover the viewport without distorting the preview's aspect ratio.
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: vm.controller!.value.previewSize?.height ?? 1,
            height: vm.controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(vm.controller!),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: GridPainter())),
        _buildTopBar(context),
        Center(child: _buildFocusFrame()),
        _buildTips(),
        _buildCaptureBar(vm),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Kembali',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Posisikan item dalam bingkai',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusFrame() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth * 0.72).clamp(200.0, 300.0);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppTheme.greenPrimary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
              _buildCorner(left: 0, top: 0, isTop: true, isLeft: true),
              _buildCorner(right: 0, top: 0, isTop: true, isRight: true),
              _buildCorner(left: 0, bottom: 0, isBottom: true, isLeft: true),
              _buildCorner(right: 0, bottom: 0, isBottom: true, isRight: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTips() {
    return Positioned(
      bottom: 150,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navyPrimary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _tips[_currentTipIndex],
                  key: ValueKey<int>(_currentTipIndex),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureBar(ScanViewModel vm) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: const Color(0xFF001E32),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: vm.isCapturing ? null : () => _capture(vm),
                icon: vm.isCapturing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(vm.isCapturing ? 'Mengambil...' : 'Ambil Gambar'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ScanViewModel vm) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64),
            const SizedBox(height: 24),
            Text(
              vm.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.initializeCamera,
                child: const Text('Coba Lagi'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Kembali'),
            ),
          ],
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
    const side = BorderSide(color: AppTheme.greenPrimary, width: 4);
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
            top: isTop ? side : BorderSide.none,
            bottom: isBottom ? side : BorderSide.none,
            left: isLeft ? side : BorderSide.none,
            right: isRight ? side : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: isTop && isLeft ? const Radius.circular(32) : Radius.zero,
            topRight: isTop && isRight ? const Radius.circular(32) : Radius.zero,
            bottomLeft: isBottom && isLeft ? const Radius.circular(32) : Radius.zero,
            bottomRight: isBottom && isRight ? const Radius.circular(32) : Radius.zero,
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
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(size.width * i / 3, 0),
        Offset(size.width * i / 3, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * i / 3),
        Offset(size.width, size.height * i / 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
