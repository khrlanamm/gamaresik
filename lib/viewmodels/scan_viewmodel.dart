import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ScanViewModel extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;

  Future<void> initializeCamera() async {
    _errorMessage = null;
    notifyListeners();

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _errorMessage = 'Tidak ada kamera yang tersedia di perangkat ini.';
        notifyListeners();
        return;
      }
      _controller = CameraController(_cameras![0], ResolutionPreset.medium);
      await _controller!.initialize();
      _isInitialized = true;
      notifyListeners();
    } on CameraException catch (e) {
      _errorMessage = e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
          ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.'
          : 'Gagal mengakses kamera. Coba lagi.';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal mengakses kamera. Coba lagi.';
      notifyListeners();
    }
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return await _controller!.takePicture();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
