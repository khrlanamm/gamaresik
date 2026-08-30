import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamaresik/models/achievement.dart';
import 'package:gamaresik/models/classification_result.dart';
import 'package:gamaresik/models/waste_category.dart';
import 'package:gamaresik/utils/app_theme.dart';
import 'package:gamaresik/views/auth/onboarding_view.dart';

void main() {
  group('WasteCategory', () {
    test('every category has a unique, stable id', () {
      final ids = WasteCategory.values.map((c) => c.id).toSet();
      expect(ids.length, WasteCategory.values.length);
    });

    test('fromId round-trips for every category', () {
      for (final category in WasteCategory.values) {
        expect(WasteCategory.fromId(category.id), category);
      }
    });

    test('fromId falls back to residual for an unknown id', () {
      expect(WasteCategory.fromId('unknown'), WasteCategory.residual);
      expect(WasteCategory.fromId(null), WasteCategory.residual);
    });

    test('classification labels match the vocabulary the backend prompts for', () {
      // These strings are the contract with CATEGORY_TO_ID in
      // functions/classifier.js, and both sides are fixed by Tabel 4.1 of the
      // thesis — changing one without the other silently breaks every scan.
      expect(WasteCategory.organic.classificationLabel, 'organik');
      expect(WasteCategory.recyclable.classificationLabel, 'recycle');
      expect(WasteCategory.residual.classificationLabel, 'residu');
    });

    test('fromClassificationLabel round-trips and falls back safely', () {
      for (final category in WasteCategory.values) {
        expect(
          WasteCategory.fromClassificationLabel(category.classificationLabel),
          category,
        );
      }
      expect(WasteCategory.fromClassificationLabel('Sampah Aneh'), WasteCategory.residual);
    });

    test('every category has non-empty display content', () {
      for (final category in WasteCategory.values) {
        expect(category.title, isNotEmpty);
        expect(category.binLabel, isNotEmpty);
        expect(category.description, isNotEmpty);
        expect(category.impact, isNotEmpty);
        expect(category.onboardingDescription, isNotEmpty);
        expect(category.sampleItems, isNotEmpty);
      }
    });
  });

  group('AchievementProgress', () {
    test('a brand new user targets the first milestone', () {
      final progress = AchievementProgress.of(0);
      expect(progress.next?.target, 50);
      expect(progress.lastUnlocked, isNull);
      expect(progress.unlockedCount, 0);
      expect(progress.progress, 0);
      expect(progress.remaining, 50);
      expect(progress.isComplete, isFalse);
    });

    test('progress measures the current band, not the whole ladder', () {
      // 75 scans sits halfway between the 50 and 100 milestones.
      final progress = AchievementProgress.of(75);
      expect(progress.lastUnlocked?.target, 50);
      expect(progress.next?.target, 100);
      expect(progress.progress, closeTo(0.5, 1e-9));
      expect(progress.remaining, 25);
    });

    test('reaching a milestone exactly unlocks it', () {
      final progress = AchievementProgress.of(50);
      expect(progress.lastUnlocked?.target, 50);
      expect(progress.next?.target, 100);
      expect(progress.unlockedCount, 1);
    });

    test('completing every milestone reports a finished state', () {
      final progress = AchievementProgress.of(5000);
      expect(progress.isComplete, isTrue);
      expect(progress.next, isNull);
      expect(progress.progress, 1.0);
      expect(progress.remaining, 0);
      expect(progress.unlockedCount, Achievement.all.length);
    });

    test('milestones are ordered ascending', () {
      final targets = Achievement.all.map((a) => a.target).toList();
      final sorted = [...targets]..sort();
      expect(targets, sorted);
    });
  });

  group('OnboardingView', () {
    testWidgets('shows the first category with its bin colour', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const OnboardingView()),
      );

      expect(find.text(WasteCategory.organic.officialName), findsOneWidget);
      expect(find.text(WasteCategory.organic.binLabel), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Selanjutnya'), findsOneWidget);
    });

    testWidgets('advances to the next category and reaches the final step',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const OnboardingView()),
      );

      await tester.tap(find.text('Selanjutnya'));
      await tester.pumpAndSettle();
      expect(find.text(WasteCategory.recyclable.officialName), findsOneWidget);

      await tester.tap(find.text('Selanjutnya'));
      await tester.pumpAndSettle();
      expect(find.text(WasteCategory.residual.officialName), findsOneWidget);
      // Last page swaps the CTA to the finish label.
      expect(find.text('Mulai'), findsOneWidget);
      expect(find.text('Selanjutnya'), findsNothing);
    });

    testWidgets('renders without overflow on a short viewport', (tester) async {
      // iPhone SE-class logical size — the layout used to overflow here.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const OnboardingView()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ClassificationResult.isLowConfidence', () {
    ClassificationResult build({
      required double confidence,
      double? threshold,
    }) {
      return ClassificationResult(
        logId: 'scan-1',
        category: WasteCategory.residual,
        label: WasteCategory.residual.classificationLabel,
        confidenceScore: confidence,
        reasoning: null,
        usedFewShot: false,
        fewShotExampleCount: 0,
        mode: 'selective',
        escalated: true,
        zeroShotConfidence: confidence,
        confidenceThreshold: threshold,
        modelId: 'gemini-3.6-flash',
        latencyMs: 1200,
        totalTokens: 900,
        thoughtsTokens: 200,
        totalScans: 1,
      );
    }

    test('flags a score below the threshold the backend applied', () {
      expect(build(confidence: 0.15, threshold: 0.5).isLowConfidence, isTrue);
    });

    test('a score exactly at the threshold is not low', () {
      // Matches the backend, which treats >= threshold as sufficient.
      expect(build(confidence: 0.5, threshold: 0.5).isLowConfidence, isFalse);
    });

    test('stays silent when the backend reported no threshold', () {
      // An older response carries no threshold; warning anyway would put copy
      // on screen the app cannot actually justify.
      expect(build(confidence: 0.05, threshold: null).isLowConfidence, isFalse);
    });
  });
}
