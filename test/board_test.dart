import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piece_finder/board.dart';
import 'package:piece_finder/main.dart';
import 'package:piece_finder/models.dart';
import 'package:piece_finder/repository.dart';

import 'fixtures.dart';
import 'widget_test.dart' show UnusedDatabase;

class PlacementRepository extends PuzzleRepository {
  PlacementRepository() : super(UnusedDatabase(), Directory.systemTemp);
  final cells = <int>{};
  @override
  Future<void> setPlaced(Puzzle puzzle, int cell, bool placed) async {
    if (placed) {
      cells.add(cell);
    } else {
      cells.remove(cell);
    }
  }
}

void main() {
  late File reference;
  setUpAll(() async {
    await Directory('.artifacts').create(recursive: true);
    reference = await File('.artifacts/test-reference.png')
        .writeAsBytes(png(referenceFixture()));
  });
  testWidgets('candidate selection marks the correct cell and supports undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = PlacementRepository();
    final puzzle = Puzzle(
      id: 'test',
      name: 'Test puzzle',
      imagePath: reference.absolute.path,
      rows: 4,
      columns: 6,
      createdAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: pieceFinderTheme(),
        home: BoardScreen(
          puzzle: puzzle,
          repository: repository,
          candidates: const [
            Candidate(row: 1, column: 2, clockwiseTurns: 0, similarity: .9),
            Candidate(row: 2, column: 3, clockwiseTurns: 1, similarity: .8),
          ],
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        FileImage(reference),
        tester.element(find.byType(BoardScreen)),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Row 2 · Column 3'), findsOneWidget);
    await tester.tap(find.text('Candidate 2'));
    await tester.pumpAndSettle();
    expect(find.text('Row 3 · Column 4'), findsOneWidget);
    expect(find.text('Rotate 90° clockwise'), findsOneWidget);
    await tester.tap(find.text('Mark as placed'));
    await tester.pumpAndSettle();
    expect(repository.cells, {15});
    expect(find.text('1 / 24 placed'), findsOneWidget);
    await tester.tap(find.text('Placed · tap to undo'));
    await tester.pumpAndSettle();
    expect(repository.cells, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
