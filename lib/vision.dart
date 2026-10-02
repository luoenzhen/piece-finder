import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'models.dart';

class VisionException implements Exception {
  const VisionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Normalized image coordinates, in TL, TR, BR, BL order for calibration.
typedef ImagePoint = ({double x, double y});

img.Image decodePhoto(Uint8List bytes, {int maxSide = 1600}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const VisionException(
      'This photo could not be read. Choose a JPEG or PNG image.',
    );
  }
  if (decoded == null) {
    throw const VisionException(
      'This photo could not be read. Choose a JPEG or PNG image.',
    );
  }
  final oriented = img.bakeOrientation(decoded);
  if (math.max(oriented.width, oriented.height) <= maxSide) return oriented;
  return img.copyResize(
    oriented,
    width: oriented.width >= oriented.height ? maxSide : null,
    height: oriented.height > oriented.width ? maxSide : null,
  );
}

Uint8List normalizePhoto(Uint8List bytes) =>
    Uint8List.fromList(img.encodeJpg(decodePhoto(bytes), quality: 92));

/// Shared corner validation and output sizing for both calibration backends.
(int, int) calibrationDimensions(
  List<ImagePoint> corners,
  int imageWidth,
  int imageHeight,
) {
  if (corners.length != 4) {
    throw const VisionException('Select all four corners.');
  }
  for (var i = 0; i < 4; i++) {
    final a = corners[i], b = corners[(i + 1) % 4], c = corners[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross < .005 || a.x < 0 || a.x > 1 || a.y < 0 || a.y > 1) {
      throw const VisionException(
        'Keep corners in order around the artwork without crossing.',
      );
    }
  }
  double distance(ImagePoint a, ImagePoint b) => math.sqrt(
    math.pow((a.x - b.x) * imageWidth, 2) +
        math.pow((a.y - b.y) * imageHeight, 2),
  );
  final width =
      ((distance(corners[0], corners[1]) + distance(corners[3], corners[2])) /
              2)
          .round()
          .clamp(32, 1600);
  final height =
      ((distance(corners[0], corners[3]) + distance(corners[1], corners[2])) /
              2)
          .round()
          .clamp(32, 1600);
  return (width, height);
}

/// Dart reference implementation, also used by the browser build.
Uint8List rectifyPhoto(Uint8List bytes, List<ImagePoint> corners) {
  final source = decodePhoto(bytes);
  final (width, height) = calibrationDimensions(
    corners,
    source.width,
    source.height,
  );
  const square = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)];
  final equations = <List<double>>[];
  for (var i = 0; i < 4; i++) {
    final (x, y) = square[i];
    final u = corners[i].x * (source.width - 1),
        v = corners[i].y * (source.height - 1);
    equations.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
    equations.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var row = col + 1; row < 8; row++) {
      if (equations[row][col].abs() > equations[pivot][col].abs()) pivot = row;
    }
    final swap = equations[col];
    equations[col] = equations[pivot];
    equations[pivot] = swap;
    final divisor = equations[col][col];
    if (divisor.abs() < 1e-10) {
      throw const VisionException('Select a larger area of artwork.');
    }
    for (var j = col; j <= 8; j++) {
      equations[col][j] /= divisor;
    }
    for (var row = 0; row < 8; row++) {
      if (row == col) continue;
      final factor = equations[row][col];
      for (var j = col; j <= 8; j++) {
        equations[row][j] -= factor * equations[col][j];
      }
    }
  }
  final h = equations.map((row) => row[8]).toList();
  final output = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final nx = x / (width - 1), ny = y / (height - 1);
      final d = h[6] * nx + h[7] * ny + 1;
      final sx = ((h[0] * nx + h[1] * ny + h[2]) / d).clamp(
        0.0,
        source.width - 1.0,
      );
      final sy = ((h[3] * nx + h[4] * ny + h[5]) / d).clamp(
        0.0,
        source.height - 1.0,
      );
      output.setPixel(
        x,
        y,
        source.getPixelInterpolate(
          sx,
          sy,
          interpolation: img.Interpolation.linear,
        ),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(output, quality: 94));
}

class PieceRegion {
  const PieceRegion(this.left, this.top, this.right, this.bottom);
  final int left, top, right, bottom;
  int get width => right - left + 1;
  int get height => bottom - top + 1;
}

/// Prototype foreground isolation. A neutral, contrasting background is required.
/// A border-connected background flood fill preserves dark printing within pieces.
PieceRegion segmentPiece(img.Image image) {
  final w = image.width, h = image.height;
  final samples = <List<int>>[[], [], []];
  void sample(int x, int y) {
    final p = image.getPixel(x, y);
    samples[0].add(p.r.toInt());
    samples[1].add(p.g.toInt());
    samples[2].add(p.b.toInt());
  }

  for (var x = 0; x < w; x += math.max(1, w ~/ 32)) {
    sample(x, 0);
    sample(x, h - 1);
  }
  for (var y = 0; y < h; y += math.max(1, h ~/ 32)) {
    sample(0, y);
    sample(w - 1, y);
  }
  final bg = samples.map((s) {
    s.sort();
    return s[s.length ~/ 2];
  }).toList();
  final visited = Uint8List(w * h);
  final queue = <int>[];
  void visit(int x, int y) {
    final index = y * w + x;
    if (visited[index] != 0) return;
    final p = image.getPixel(x, y);
    final distance = math.max(
      (p.r - bg[0]).abs(),
      math.max((p.g - bg[1]).abs(), (p.b - bg[2]).abs()),
    );
    if (distance > 42) return;
    visited[index] = 1;
    queue.add(index);
  }

  for (var x = 0; x < w; x++) {
    visit(x, 0);
    visit(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    visit(0, y);
    visit(w - 1, y);
  }
  for (var head = 0; head < queue.length; head++) {
    final x = queue[head] % w, y = queue[head] ~/ w;
    if (x > 0) visit(x - 1, y);
    if (x + 1 < w) visit(x + 1, y);
    if (y > 0) visit(x, y - 1);
    if (y + 1 < h) visit(x, y + 1);
  }
  var largest = <int>[];
  for (var index = 0; index < visited.length; index++) {
    if (visited[index] != 0) continue;
    final component = <int>[index];
    visited[index] = 2;
    for (var head = 0; head < component.length; head++) {
      final current = component[head], x = current % w, y = current ~/ w;
      for (final next in [
        if (x > 0) current - 1,
        if (x + 1 < w) current + 1,
        if (y > 0) current - w,
        if (y + 1 < h) current + w,
      ]) {
        if (visited[next] == 0) {
          visited[next] = 2;
          component.add(next);
        }
      }
    }
    if (component.length > largest.length) largest = component;
  }
  if (largest.length < w * h * .015 || largest.length > w * h * .85) {
    throw const VisionException(
      'Place one piece on plain contrasting paper, leave a clear margin, and photograph from directly above.',
    );
  }
  final xs = List<int>.filled(w, 0), ys = List<int>.filled(h, 0);
  for (final index in largest) {
    xs[index % w]++;
    ys[index ~/ w]++;
  }
  // Tab tips occupy fewer scan lines than the body. Exclude them from scale estimation.
  final xThreshold = xs.reduce(math.max) * .55,
      yThreshold = ys.reduce(math.max) * .55;
  final left = xs.indexWhere((n) => n >= xThreshold),
      right = xs.lastIndexWhere((n) => n >= xThreshold);
  final top = ys.indexWhere((n) => n >= yThreshold),
      bottom = ys.lastIndexWhere((n) => n >= yThreshold);
  if (right - left < 12 || bottom - top < 12) {
    throw const VisionException(
      'Move closer so the piece fills more of the frame.',
    );
  }
  return PieceRegion(left, top, right, bottom);
}

List<double> _features(
  img.Image image,
  double left,
  double top,
  double width,
  double height,
) {
  final values = <double>[];
  const side = 12;
  for (var y = 0; y < side; y++) {
    for (var x = 0; x < side; x++) {
      final px = left + (.25 + .5 * (x + .5) / side) * width;
      final py = top + (.25 + .5 * (y + .5) / side) * height;
      final p = image.getPixelInterpolate(
        px.clamp(0.0, image.width - 1.0),
        py.clamp(0.0, image.height - 1.0),
        interpolation: img.Interpolation.linear,
      );
      values.addAll([p.r.toDouble(), p.g.toDouble(), p.b.toDouble()]);
    }
  }
  return values;
}

double _variance(List<double> data) {
  final mean = data.reduce((a, b) => a + b) / data.length;
  return data.fold<double>(0, (sum, n) => sum + (n - mean) * (n - mean)) /
      data.length;
}

double _similarity(List<double> a, List<double> b) {
  var correlation = 0.0, colorError = 0.0;
  for (var channel = 0; channel < 3; channel++) {
    var ma = 0.0, mb = 0.0;
    final count = a.length ~/ 3;
    for (var i = channel; i < a.length; i += 3) {
      ma += a[i];
      mb += b[i];
    }
    ma /= count;
    mb /= count;
    var aa = 0.0, bb = 0.0, ab = 0.0;
    for (var i = channel; i < a.length; i += 3) {
      final da = a[i] - ma, db = b[i] - mb;
      aa += da * da;
      bb += db * db;
      ab += da * db;
    }
    correlation += aa < 1 || bb < 1 ? 0 : ab / math.sqrt(aa * bb);
    colorError += (ma - mb).abs() / 255;
  }
  return (.85 * math.max(0, correlation / 3) + .15 * (1 - colorError / 3))
      .clamp(0, 1);
}

/// CPU reference implementation for validating the native engine in later work.
/// Runs in a worker isolate in the app. Scores are similarities, not probabilities.
ScanResult matchPiece({
  required Uint8List referenceBytes,
  required Uint8List pieceBytes,
  required int rows,
  required int columns,
}) {
  if (rows < 1 || columns < 1 || rows * columns > 10000) {
    throw const VisionException('Check the puzzle grid dimensions.');
  }
  final timer = Stopwatch()..start();
  final reference = decodePhoto(referenceBytes);
  final piece = decodePhoto(pieceBytes, maxSide: 480);
  final region = segmentPiece(piece);
  final body = img.copyCrop(
    piece,
    x: region.left,
    y: region.top,
    width: region.width,
    height: region.height,
  );
  final rotations = List.generate(4, (turn) {
    final rotated = img.copyRotate(body, angle: turn * 90);
    return _features(
      rotated,
      0,
      0,
      rotated.width.toDouble(),
      rotated.height.toDouble(),
    );
  });
  // Measure spatial variance independently of channel differences (solid red is still flat).
  var spatialVariance = 0.0;
  for (var c = 0; c < 3; c++) {
    spatialVariance += _variance([
      for (var i = c; i < rotations.first.length; i += 3) rotations.first[i],
    ]);
  }
  final candidates = <Candidate>[];
  final cw = reference.width / columns, ch = reference.height / rows;
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      var bestScore = -1.0, bestTurn = 0;
      for (final dx in [-.12, 0.0, .12]) {
        for (final dy in [-.12, 0.0, .12]) {
          final features = _features(
            reference,
            (column + dx) * cw,
            (row + dy) * ch,
            cw,
            ch,
          );
          for (var turn = 0; turn < 4; turn++) {
            final score = _similarity(rotations[turn], features);
            if (score > bestScore) {
              bestScore = score;
              bestTurn = turn;
            }
          }
        }
      }
      candidates.add(
        Candidate(
          row: row,
          column: column,
          clockwiseTurns: bestTurn,
          similarity: bestScore,
        ),
      );
    }
  }
  candidates.sort((a, b) => b.similarity.compareTo(a.similarity));
  return ScanResult(
    candidates: candidates.take(3).toList(),
    lowTexture: spatialVariance / 3 < 35,
    elapsedMs: timer.elapsedMilliseconds,
  );
}
