import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/firebase_service.dart';

class HistoryViewModel extends ChangeNotifier {
  final GamaBackend _backend;

  HistoryViewModel({GamaBackend? backend}) : _backend = backend ?? FirebaseService();

  /// Most recent scans shown. Older entries exist in Firestore but are not
  /// fetched; [hasMore] lets the UI say so rather than implying this is
  /// everything.
  static const int pageLimit = 50;

  List<ScanRecord> _records = [];
  List<ScanRecord> get records => _records;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDisposed = false;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// True when the query filled the page, so more history probably exists.
  bool get hasMore => _records.length >= pageLimit;

  Future<void> fetchHistory() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();
    try {
      _records = await _backend.getScanHistory(limit: pageLimit);
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat. Periksa koneksi Anda lalu coba lagi.';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Popping the view mid-fetch would otherwise notify a disposed notifier
  /// from the finally block above.
  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
