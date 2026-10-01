import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:piece_finder/vision.dart';

import 'fixtures.dart';

void main() {
  group('Known placement and rotation', () {
    for (var turns = 0; turns < 4; turns++) {
      test('recovers a piece photographed at ${turns * 90} degrees', () {
        final reference = referenceFixture();
        final result = matchPiece(
          referenceBytes: png(reference),
          pieceBytes: pieceFixture(reference, turns: turns, tabs: true),
          rows: 4,
          columns: 6,
        );
        expect(result.candidates.first.row, 2);
        expect(result.candidates.first.column, 3);
        expect(result.candidates.first.clockwiseTurns, (4 - turns) % 4);
        expect(result.candidates.first.similarity, greaterThan(.9));
        expect(result.lowTexture, isFalse);
        expect(
          result.candidates.map((c) => (c.row, c.column)).toSet().length,
          3,
        );
      });
    }
    test('handles rectangular pieces', () {
      final reference = referenceFixture(cellWidth: 72, cellHeight: 54);
      final result = matchPiece(
        referenceBytes: png(reference),
        pieceBytes: pieceFixture(
          reference,
          cellWidth: 72,
          cellHeight: 54,
          turns: 1,
        ),
        rows: 4,
        columns: 6,
      );
      expect(
        (result.candidates.first.row, result.candidates.first.column),
        (2, 3),
      );
      expect(result.candidates.first.clockwiseTurns, 3);
    });
  });
  test('uniform colored pieces remain ambiguous', () {
    final reference = img.Image(width: 256, height: 256);
    img.fill(reference, color: img.ColorRgb8(80, 120, 170));
    final result = matchPiece(
      referenceBytes: png(reference),
      pieceBytes: pieceFixture(reference, row: 1, column: 1),
      rows: 4,
      columns: 4,
    );
    expect(result.lowTexture, isTrue);
    expect(result.isAmbiguous, isTrue);
    expect(result.candidates.length, 3);
  });
  test(
    'blank capture produces actionable error instead of fabricated matches',
    () {
      final blank = img.Image(width: 128, height: 128);
      img.fill(blank, color: img.ColorRgb8(250, 250, 250));
      expect(() => segmentPiece(blank), throwsA(isA<VisionException>()));
    },
  );
  test('invalid image and grid inputs fail safely', () {
    expect(
      () => decodePhoto(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<VisionException>()),
    );
    expect(
      () => matchPiece(
        referenceBytes: Uint8List(0),
        pieceBytes: Uint8List(0),
        rows: 0,
        columns: 4,
      ),
      throwsA(isA<VisionException>()),
    );
  });
  test('rectification preserves orientation and excludes margins', () {
    final source = img.Image(width: 200, height: 120);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    img.fillRect(
      source,
      x1: 20,
      y1: 12,
      x2: 179,
      y2: 107,
      color: img.ColorRgb8(140, 60, 40),
    );
    final output = decodePhoto(
      rectifyPhoto(png(source), [
        (x: .1, y: .1),
        (x: .9, y: .1),
        (x: .9, y: .9),
        (x: .1, y: .9),
      ]),
    );
    expect(output.width, 160);
    expect(output.height, 96);
    final center = output.getPixel(80, 48);
    expect(center.r, closeTo(140, 5));
    expect(center.g, closeTo(60, 5));
  });
  test('crossed calibration corners are rejected', () {
    expect(
      () => rectifyPhoto(png(referenceFixture()), [
        (x: 0, y: 0),
        (x: 1, y: 1),
        (x: 1, y: 0),
        (x: 0, y: 1),
      ]),
      throwsA(isA<VisionException>()),
    );
  });
}
