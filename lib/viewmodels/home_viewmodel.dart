import 'package:flutter/material.dart';
import '../models/waste_category.dart';
import '../services/firebase_service.dart';

class HomeViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  static const List<int> _targets = [50, 100, 200, 500, 1000, 5000, 10000];

  bool _isLoading = false;
  int _totalScanned = 0;
  Map<WasteCategory, int> _categoryCounts = {
    for (final category in WasteCategory.values) category: 0,
  };

  bool get isLoading => _isLoading;
  int get totalScanned => _totalScanned;
  Map<WasteCategory, int> get categoryCounts => _categoryCounts;

  int get nextTarget {
    for (final target in _targets) {
      if (_totalScanned < target) return target;
    }
    return _targets.last;
  }

  double get progress => nextTarget == 0 ? 0.0 : (_totalScanned / nextTarget).clamp(0.0, 1.0);

  Future<void> fetchTotalScanned() async {
    _isLoading = true;
    notifyListeners();

    _totalScanned = await _firebaseService.getClassificationCount();
    _categoryCounts = await _firebaseService.getCategoryCounts();

    _isLoading = false;
    notifyListeners();
  }
}
