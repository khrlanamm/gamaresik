import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/user_stats.dart';
import '../models/waste_category.dart';
import '../services/firebase_service.dart';

class HomeViewModel extends ChangeNotifier {
  final GamaBackend _backend;

  HomeViewModel({GamaBackend? backend}) : _backend = backend ?? FirebaseService();

  UserStats _stats = UserStats.empty();
  bool _isLoading = false;
  String? _errorMessage;

  UserStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalScanned => _stats.totalScans;
  Map<WasteCategory, int> get categoryCounts => _stats.categoryCounts;

  AchievementProgress get achievementProgress =>
      AchievementProgress.of(_stats.totalScans);

  /// Reads the server-maintained aggregate counters.
  ///
  /// Always clears the loading flag, including on failure — an unhandled throw
  /// here previously left the home screen spinning forever.
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stats = await _backend.getUserStats();
    } catch (e) {
      _errorMessage = 'Gagal memuat statistik. Tarik ke bawah untuk mencoba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
