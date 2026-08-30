import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class ScanViewModel extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isDisposed = false;
  String? _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  String? get errorMessage => _errorMessage;

  /// Guards against notifying after the view is gone, which throws.
  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> initializeCamera() async {
    _errorMessage = null;
    _isInitialized = false;
    _safeNotify();

    try {
      _cameras ??= await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _errorMessage = 'Tidak ada kamera yang tersedia di perangkat ini.';
        _safeNotify();
        return;
      }

      final controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      // The view may have been popped while initialize() was in flight.
      if (_isDisposed) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _isInitialized = true;
      _safeNotify();
    } on CameraException catch (e) {
      _errorMessage = _messageForCameraException(e);
      _safeNotify();
    } catch (e) {
      _errorMessage = 'Gagal mengakses kamera. Coba lagi.';
      _safeNotify();
    }
  }

  String _messageForCameraException(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.';
      case 'cameraNotFound':
        return 'Kamera tidak ditemukan di perangkat ini.';
      default:
        return 'Gagal mengakses kamera. Coba lagi.';
    }
  }

  /// Captures a still. Returns null if the camera is not ready or a capture is
  /// already running — without this guard, a fast double-tap fires two
  /// captures and pushes two result screens.
  Future<XFile?> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    if (_isCapturing) return null;

    _isCapturing = true;
    _safeNotify();
    try {
      return await controller.takePicture();
    } on CameraException catch (e) {
      _errorMessage = _messageForCameraException(e);
      _safeNotify();
      return null;
    } finally {
      _isCapturing = false;
      _safeNotify();
    }
  }

  /// Releases the camera when the app goes to the background; Android in
  /// particular revokes the handle and resuming with a stale one throws.
  Future<void> releaseForBackground() async {
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    _safeNotify();
    await controller?.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
