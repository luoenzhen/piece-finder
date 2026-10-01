import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piece_finder/main.dart';
import 'package:piece_finder/repository.dart';

import '../test/fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
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
