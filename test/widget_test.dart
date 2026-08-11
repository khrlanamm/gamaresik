import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gamaresik/models/waste_category.dart';
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

    test('every category has non-empty display content', () {
      for (final category in WasteCategory.values) {
        expect(category.title, isNotEmpty);
        expect(category.binLabel, isNotEmpty);
        expect(category.description, isNotEmpty);
        expect(category.impact, isNotEmpty);
        expect(category.sampleItems, isNotEmpty);
      }
    });
  });

  testWidgets('OnboardingView shows the first waste category page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingView()));

    expect(find.text('Sampah Organik'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Selanjutnya'), findsOneWidget);
  });
}
