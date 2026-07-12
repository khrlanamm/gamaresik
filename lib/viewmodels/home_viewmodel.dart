import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class HomeViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  int _totalScanned = 0;
  Map<String, int> _categoryCounts = {
    'Organik Terpilah': 0,
    'Recycle Bersih': 0,
    'Residu Terpilah': 0,
  };
  final List<int> _targets = [50, 100, 1000, 10000, 50000, 100000];

  int get totalScanned => _totalScanned;
  Map<String, int> get categoryCounts => _categoryCounts;

  int get nextTarget {
    for (int target in _targets) {
      if (_totalScanned < target) {
        return target;
      }
    }
    return _targets.last;
  }

  Future<void> fetchTotalScanned() async {
    _totalScanned = await _firebaseService.getClassificationCount();
    _categoryCounts = await _firebaseService.getCategoryCounts();
    notifyListeners();
  }
}
