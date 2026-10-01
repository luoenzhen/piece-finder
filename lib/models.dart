import 'dart:math' as math;

class PuzzleGrid {
  const PuzzleGrid(this.rows, this.columns);
  final int rows;
  final int columns;
  int get count => rows * columns;

  static PuzzleGrid estimate(int count, double aspectRatio) {
    var best = const PuzzleGrid(1, 1);
    var error = double.infinity;
    for (var rows = 2; rows <= math.sqrt(count) * 2; rows++) {
      if (count % rows != 0) continue;
      final columns = count ~/ rows;
      final next = ((columns / rows) / aspectRatio).logAbs();
      if (next < error) {
        best = PuzzleGrid(rows, columns);
        error = next;
      }
    }
    return best;
  }
}

extension on double {
  double logAbs() => math.log(this).abs();
}

class Puzzle {
  const Puzzle({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.rows,
    required this.columns,
    required this.createdAt,
    this.placed = const {},
  });
  final String id;
  final String name;
  final String imagePath;
  final int rows;
  final int columns;
  final DateTime createdAt;
  final Set<int> placed;
  int get count => rows * columns;
}

class Candidate {
  const Candidate({
    required this.row,
    required this.column,
    required this.clockwiseTurns,
    required this.similarity,
  });
  final int row;
  final int column;

  /// Rotation to apply to the photographed piece to align it with the board.
  final int clockwiseTurns;
  final double similarity;
  Map<String, Object> toJson() => {
    'row': row,
    'column': column,
    'turns': clockwiseTurns,
    'similarity': similarity,
  };
  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
    row: json['row'] as int,
    column: json['column'] as int,
    clockwiseTurns: json['turns'] as int,
    similarity: (json['similarity'] as num).toDouble(),
  );
}

class ScanResult {
  const ScanResult({
    required this.candidates,
    required this.lowTexture,
    required this.elapsedMs,
  });
  final List<Candidate> candidates;
  final bool lowTexture;
  final int elapsedMs;
  bool get isAmbiguous =>
      lowTexture ||
      candidates.isEmpty ||
      candidates.first.similarity < .8 ||
      (candidates.length > 1 &&
          candidates.first.similarity - candidates[1].similarity < .06);
}

class ScanQuota {
  const ScanQuota({required this.used, required this.startedAt});
  static const limit = 5;
  final int used;
  final DateTime startedAt;
  bool expired(DateTime now) =>
      now.difference(startedAt) >= const Duration(hours: 24);
  int remaining(DateTime now) =>
      expired(now) ? limit : math.max(0, limit - used);
  DateTime get resetsAt => startedAt.add(const Duration(hours: 24));
}
