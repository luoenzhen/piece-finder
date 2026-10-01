import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piece_finder/vision.dart';

import 'fixtures.dart';

void main() {
  test('reference matcher recovers known cells on 500 and 1000 piece synthetic boards', () async {
    final measurements = <Map<String, Object>>[];
    for (final (rows, columns) in [(20, 25), (25, 40)]) {
      final reference = referenceFixture(
        rows: rows,
        columns: columns,
        cellWidth: 32,
        cellHeight: 32,
      );
      final result = matchPiece(
        referenceBytes: png(reference),
        pieceBytes: pieceFixture(
          reference,
          row: 12,
          column: 17,
          cellWidth: 32,
          cellHeight: 32,
          turns: 3,
        ),
        rows: rows,
        columns: columns,
      );
      expect(
        (result.candidates.first.row, result.candidates.first.column),
        (12, 17),
      );
      expect(result.candidates.first.clockwiseTurns, 1);
      measurements.add({
        'pieces': rows * columns,
        'elapsedMs': result.elapsedMs,
        'topSimilarity': result.candidates.first.similarity,
        'fixture': 'synthetic aligned crop with known placement, not real camera photographs',
      });
    }
    await Directory('.artifacts').create(recursive: true);
    await File('.artifacts/reference-benchmark.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'platform': Platform.operatingSystem,
        'runtime': 'Flutter test / host CPU, not physical iPhone',
        'measurements': measurements,
      }),
    );
  });
}
