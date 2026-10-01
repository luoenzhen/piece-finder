import 'package:flutter_test/flutter_test.dart';
import 'package:piece_finder/models.dart';

void main() {
  test(
    'grid estimates preserve count for each supported count and orientation',
    () {
      for (final count in [300, 500, 1000, 1500, 2000]) {
        for (final ratio in [.7, 1.0, 1.5, 2.0]) {
          final grid = PuzzleGrid.estimate(count, ratio);
          expect(grid.count, count);
          expect(grid.rows, greaterThan(1));
          expect(grid.columns, greaterThan(1));
        }
      }
    },
  );
  test('quota resets after exactly 24 hours, never on clock rollback', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final quota = ScanQuota(used: 5, startedAt: now);
    expect(quota.remaining(now.add(const Duration(hours: 23, minutes: 59))), 0);
    expect(quota.remaining(now.add(const Duration(hours: 24))), 5);
    expect(quota.remaining(now.subtract(const Duration(days: 1))), 0);
  });
  test('similar top scores are ambiguous even with high similarity', () {
    const result = ScanResult(
      candidates: [
        Candidate(row: 0, column: 0, clockwiseTurns: 0, similarity: .95),
        Candidate(row: 1, column: 0, clockwiseTurns: 0, similarity: .94),
      ],
      lowTexture: false,
      elapsedMs: 100,
    );
    expect(result.isAmbiguous, isTrue);
  });
}
