import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:piece_finder/models.dart';
import 'package:piece_finder/repository.dart';

import 'fixtures.dart';

void main() {
  late PuzzleRepository repository;
  late Directory directory;
  late Database database;
  late Puzzle puzzle;
  const result = ScanResult(
    candidates: [
      Candidate(row: 2, column: 3, clockwiseTurns: 1, similarity: .9),
    ],
    lowTexture: false,
    elapsedMs: 150,
  );
  setUp(() async {
    sqfliteFfiInit();
    directory = await Directory.systemTemp.createTemp('piecefinder-test-');
    database = await databaseFactoryFfi.openDatabase(
      '${directory.path}/test.db',
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PuzzleRepository.createSchema,
      ),
    );
    repository = PuzzleRepository(database, directory.path);
    puzzle = await repository.create(
      name: 'Test puzzle',
      reference: png(referenceFixture()),
      rows: 4,
      columns: 6,
    );
  });
  tearDown(() async {
    await database.close();
    if (directory.parent.path == Directory.systemTemp.path &&
        directory.path.contains('piecefinder-test-')) {
      await directory.delete(recursive: true);
    }
  });
  test(
    'project, relative image path and placements survive database reopening',
    () async {
      await repository.setPlaced(puzzle, 15, true);
      await repository.setPlaced(puzzle, 15, true);
      await database.close();
      database = await databaseFactoryFfi.openDatabase(
        '${directory.path}/test.db',
      );
      repository = PuzzleRepository(database, directory.path);
      final saved = (await repository.puzzles()).single;
      expect(saved.name, puzzle.name);
      expect(saved.placed, {15});
      expect(await File(saved.imagePath).exists(), isTrue);
      await repository.setPlaced(saved, 15, false);
      expect((await repository.puzzles()).single.placed, isEmpty);
    },
  );
  test('scans remain unlimited with an exhausted legacy quota', () async {
    final now = DateTime.utc(2026, 10, 2, 12);
    await database.execute(
      'CREATE TABLE quota (id INTEGER PRIMARY KEY, started TEXT NOT NULL, used INTEGER NOT NULL)',
    );
    await database.insert('quota', {
      'id': 1,
      'started': now.toIso8601String(),
      'used': 5,
    });
    for (var i = 0; i < 20; i++) {
      await repository.saveScan(puzzle, result, now: now);
    }
    expect((await repository.history(puzzle)).length, 20);
    expect(
      (await repository.history(puzzle)).first.candidates.single.clockwiseTurns,
      1,
    );
  });
  test('deletion removes associated scans, placements and reference', () async {
    await repository.setPlaced(puzzle, 0, true);
    await repository.saveScan(puzzle, result);
    await repository.delete(puzzle);
    expect(await repository.puzzles(), isEmpty);
    expect(await database.query('scans'), isEmpty);
    expect(await database.query('placements'), isEmpty);
    expect(await File(puzzle.imagePath).exists(), isFalse);
  });
}
