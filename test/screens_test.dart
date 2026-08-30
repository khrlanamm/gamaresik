import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:gamaresik/models/scan_record.dart';
import 'package:gamaresik/models/user_stats.dart';
import 'package:gamaresik/models/waste_category.dart';
import 'package:gamaresik/utils/app_theme.dart';
import 'package:gamaresik/viewmodels/auth_viewmodel.dart';
import 'package:gamaresik/viewmodels/history_viewmodel.dart';
import 'package:gamaresik/viewmodels/home_viewmodel.dart';
import 'package:gamaresik/views/history/history_view.dart';
import 'package:gamaresik/views/home/home_view.dart';
import 'package:gamaresik/views/home/learn_tips_view.dart';
import 'package:gamaresik/views/profile/profile_view.dart';

import 'fake_backend.dart';

UserStats statsWith({
  required int total,
  int organic = 0,
  int recyclable = 0,
  int residual = 0,
}) {
  return UserStats(
    totalScans: total,
    categoryCounts: {
      WasteCategory.organic: organic,
      WasteCategory.recyclable: recyclable,
      WasteCategory.residual: residual,
    },
    lastScanAt: DateTime(2026, 8, 12, 9, 30),
  );
}

ScanRecord recordWith({
  String id = 'r1',
  WasteCategory category = WasteCategory.organic,
  double confidence = 0.91,
  bool corrected = false,
  WasteCategory? correctedCategory,
  bool usedFewShot = false,
}) {
  return ScanRecord(
    id: id,
    category: category,
    predictedLabel: category.officialName,
    confidenceScore: confidence,
    reasoning: 'alasan',
    imageUrl: null,
    classificationMode: 'selective',
    usedFewShot: usedFewShot,
    corrected: corrected,
    correctedCategory: correctedCategory,
    timestamp: DateTime(2026, 8, 12, 9, 30),
  );
}

/// Gives a test a viewport tall enough that lazily-built list children are
/// all constructed, so finders do not miss off-screen content.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget wrap(Widget child, FakeBackend backend) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthViewModel(backend: backend)),
      ChangeNotifierProvider(create: (_) => HomeViewModel(backend: backend)),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  group('HomeView', () {
    testWidgets('renders all three UGM categories with their bin colours',
        (tester) async {
      useTallViewport(tester);
      final backend = FakeBackend(stats: statsWith(total: 12, organic: 7, residual: 5));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      for (final category in WasteCategory.values) {
        expect(find.text(category.officialName), findsOneWidget);
        expect(find.text(category.binLabel), findsOneWidget);
      }
    });

    testWidgets('shows the persisted scan total and per-category counts',
        (tester) async {
      useTallViewport(tester);
      final backend = FakeBackend(stats: statsWith(total: 12, organic: 7, residual: 5));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      expect(backend.statsCalls, greaterThan(0), reason: 'must read server stats');
      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('surfaces an error banner instead of spinning forever',
        (tester) async {
      final backend = FakeBackend(statsError: Exception('offline'));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal memuat statistik'), findsOneWidget);
      // The failure must resolve the loading state, not hang it.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('advertises the next milestone for a new user', (tester) async {
      final backend = FakeBackend(stats: statsWith(total: 0));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      expect(find.text('Pemilah Pemula'), findsOneWidget);
      expect(find.textContaining('Kurang 50 scan lagi'), findsOneWidget);
      expect(find.text('0/4'), findsOneWidget);
    });

    testWidgets('reports completion once every milestone is reached',
        (tester) async {
      final backend = FakeBackend(stats: statsWith(total: 1500, organic: 1500));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      expect(find.text('Semua milestone tercapai'), findsWidgets);
      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('lays out without overflow on a small phone', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final backend = FakeBackend(stats: statsWith(total: 1234, organic: 1234));
      await tester.pumpWidget(wrap(const HomeView(), backend));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('HistoryView', () {
    testWidgets('shows an empty state when there are no scans', (tester) async {
      final backend = FakeBackend(history: const []);
      await tester.pumpWidget(
        wrap(HistoryView(viewModel: HistoryViewModel(backend: backend)), backend),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada riwayat scan'), findsOneWidget);
    });

    testWidgets('lists scans with their confidence', (tester) async {
      final backend = FakeBackend(history: [
        recordWith(id: 'a', category: WasteCategory.organic, confidence: 0.91),
        recordWith(id: 'b', category: WasteCategory.residual, confidence: 0.42),
      ]);
      await tester.pumpWidget(
        wrap(HistoryView(viewModel: HistoryViewModel(backend: backend)), backend),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keyakinan 91%'), findsOneWidget);
      expect(find.text('Keyakinan 42%'), findsOneWidget);
      expect(find.text('12 Agu 2026, 09:30'), findsNWidgets(2));
    });

    testWidgets('a corrected scan displays the corrected category', (tester) async {
      final backend = FakeBackend(history: [
        recordWith(
          category: WasteCategory.organic,
          corrected: true,
          correctedCategory: WasteCategory.residual,
        ),
      ]);
      await tester.pumpWidget(
        wrap(HistoryView(viewModel: HistoryViewModel(backend: backend)), backend),
      );
      await tester.pumpAndSettle();

      // The human correction must win over the model's original guess.
      expect(find.text(WasteCategory.residual.officialName), findsOneWidget);
      expect(find.text(WasteCategory.organic.officialName), findsNothing);
      expect(find.text('Dikoreksi'), findsOneWidget);
    });

    testWidgets('shows a retry action when loading fails', (tester) async {
      final backend = FakeBackend(historyError: Exception('offline'));
      await tester.pumpWidget(
        wrap(HistoryView(viewModel: HistoryViewModel(backend: backend)), backend),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat riwayat'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      backend.historyError = null;
      backend.history = [recordWith()];
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Keyakinan 91%'), findsOneWidget);
    });

    testWidgets('says so when the page limit hides older scans', (tester) async {
      final backend = FakeBackend(history: [
        for (var i = 0; i < HistoryViewModel.pageLimit; i++) recordWith(id: 'r$i'),
      ]);
      await tester.pumpWidget(
        wrap(HistoryView(viewModel: HistoryViewModel(backend: backend)), backend),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('scan terbaru'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('scan terbaru'), findsOneWidget);
    });
  });

  group('ProfileView', () {
    testWidgets('shows the signed-in user and their milestone progress',
        (tester) async {
      final backend = FakeBackend(stats: statsWith(total: 75, organic: 75));
      await tester.pumpWidget(wrap(const ProfileView(), backend));
      await tester.pumpAndSettle();

      expect(find.text('Mahasiswa UGM'), findsOneWidget);
      expect(find.text('mahasiswa@ugm.ac.id'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      // 75 scans unlocks only the first milestone.
      expect(find.text('1/4'), findsWidgets);
      expect(find.text('Tercapai'), findsOneWidget);
    });

    testWidgets('confirms before signing out', (tester) async {
      final backend = FakeBackend();
      await tester.pumpWidget(wrap(const ProfileView(), backend));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Keluar'), 300);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Keluar dari akun?'), findsOneWidget);

      // Cancelling must not sign the user out.
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(backend.currentUser, isNotNull);
    });
  });

  group('LearnTipsView', () {
    testWidgets('teaches all three categories with bin colours', (tester) async {
      useTallViewport(tester);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const LearnTipsView()),
      );
      await tester.pumpAndSettle();

      for (final category in WasteCategory.values) {
        expect(find.text(category.officialName), findsOneWidget);
        expect(find.text(category.binLabel), findsOneWidget);
      }
    });
  });
}
