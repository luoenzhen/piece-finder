import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

img.Image referenceFixture({
  int rows = 4,
  int columns = 6,
  int cellWidth = 64,
  int cellHeight = 64,
}) {
  final image = img.Image(
    width: columns * cellWidth,
    height: rows * cellHeight,
  );
  final random = Random(72819);
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < columns; col++) {
      final phase = List.generate(9, (_) => random.nextDouble() * pi * 2);
      for (var y = 0; y < cellHeight; y++) {
        for (var x = 0; x < cellWidth; x++) {
          final channels = List.generate(
            3,
            (c) =>
                (100 +
                        40 * sin(x / 7 + phase[c]) +
                        32 * cos(y / 9 + phase[c + 3]) +
                        22 * sin((x + y) / 5 + phase[c + 6]))
                    .round(),
          );
          image.setPixelRgb(
            col * cellWidth + x,
            row * cellHeight + y,
            channels[0],
            channels[1],
            channels[2],
          );
        }
      }
    }
  }
  return image;
}

Uint8List png(img.Image image) => Uint8List.fromList(img.encodePng(image));

Uint8List pieceFixture(
  img.Image reference, {
  int row = 2,
  int column = 3,
  int cellWidth = 64,
  int cellHeight = 64,
  int turns = 0,
  bool tabs = false,
}) {
  final piece = img.Image(width: cellWidth + 48, height: cellHeight + 48);
  img.fill(piece, color: img.ColorRgb8(248, 248, 248));
  for (var y = -12; y < cellHeight + 12; y++) {
    for (var x = -12; x < cellWidth + 12; x++) {
      final body = x >= 0 && x < cellWidth && y >= 0 && y < cellHeight;
      final tab = tabs && pow(x - cellWidth / 2, 2) + pow(y, 2) < 100;
      final blank =
          tabs && pow(x - cellWidth, 2) + pow(y - cellHeight / 2, 2) < 100;
      if ((body || tab) && !blank) {
        piece.setPixel(
          x + 24,
          y + 24,
          reference.getPixel(
            (column * cellWidth + x).clamp(0, reference.width - 1),
            (row * cellHeight + y).clamp(0, reference.height - 1),
          ),
        );
      }
    }
  }
  return png(img.copyRotate(piece, angle: turns * 90));
}
