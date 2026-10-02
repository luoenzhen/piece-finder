import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piece_finder/main.dart';
import 'package:piece_finder/repository.dart';
import 'package:piece_finder/calibration.dart' as calibration;
import 'package:piece_finder/vision.dart' as reference;

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native perspective warp agrees with the reference implementation',
    (tester) async {
      final bytes = png(referenceFixture());
      final corners = <reference.ImagePoint>[
        (x: .1, y: .12),
        (x: .88, y: .05),
        (x: .95, y: .9),
        (x: .05, y: .95),
      ];
      final expected = reference.decodePhoto(
        reference.rectifyPhoto(bytes, corners),
      );
      final actual = reference.decodePhoto(
        calibration.rectifyPhoto(bytes, corners),
      );
      expect((actual.width, actual.height), (expected.width, expected.height));
      var error = 0.0;
      var samples = 0;
      for (var y = 8; y < actual.height - 8; y += 9) {
        for (var x = 8; x < actual.width - 8; x += 9) {
          final a = actual.getPixel(x, y), b = expected.getPixel(x, y);
          error += (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
          samples += 3;
        }
      }
      expect(error / samples, lessThan(5));
      expect(
        () => calibration.rectifyPhoto(bytes, [
          corners[0],
          corners[2],
          corners[1],
          corners[3],
        ]),
        throwsA(isA<reference.VisionException>()),
      );
    },
  );
  testWidgets(
    'native SQLite library opens, persists a puzzle and displays its board',
    (tester) async {
      final repository = await PuzzleRepository.open();
      final puzzle = await repository.create(
        name: 'Integration test puzzle',
        reference: png(referenceFixture()),
        rows: 4,
        columns: 6,
      );
      try {
        await repository.setPlaced(puzzle, 15, true);
        await tester.pumpWidget(PieceFinderApp(repository: repository));
        await tester.pumpAndSettle();
        expect(find.text('Integration test puzzle'), findsOneWidget);
        expect(find.text('24 pieces · 1 placed'), findsOneWidget);
        await tester.ensureVisible(find.byType(Image).first);
        await tester.tap(find.byType(Image).first);
        await tester.pumpAndSettle();
        expect(find.text('1 / 24 placed'), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.delete(puzzle);
        await repository.db.close();
      }
    },
  );
}
