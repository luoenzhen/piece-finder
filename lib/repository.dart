import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import 'models.dart';
import 'storage.dart';

class PuzzleRepository {
  PuzzleRepository(this.db, String directory)
    : storage = PuzzleStorage(db, directory);
  final Database db;
  final PuzzleStorage storage;

  static Future<PuzzleRepository> open() async {
    final storage = await PuzzleStorage.open(createSchema);
    return PuzzleRepository(storage.db, storage.directory);
  }

  Future<Uint8List> readReference(Puzzle puzzle) =>
      storage.read(puzzle.imagePath);

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE puzzles (id TEXT PRIMARY KEY, name TEXT NOT NULL, image TEXT NOT NULL, rows INTEGER NOT NULL, columns INTEGER NOT NULL, created TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE placements (puzzle_id TEXT NOT NULL REFERENCES puzzles(id) ON DELETE CASCADE, cell INTEGER NOT NULL, PRIMARY KEY(puzzle_id, cell))',
    );
    await db.execute(
      'CREATE TABLE scans (id INTEGER PRIMARY KEY, puzzle_id TEXT NOT NULL REFERENCES puzzles(id) ON DELETE CASCADE, created TEXT NOT NULL, candidates TEXT NOT NULL, low_texture INTEGER NOT NULL, elapsed_ms INTEGER NOT NULL)',
    );
  }

  Future<List<Puzzle>> puzzles() async {
    final records = await db.query('puzzles', orderBy: 'created DESC');
    final placements = await db.query('placements');
    return records
        .map(
          (row) => Puzzle(
            id: row['id'] as String,
            name: row['name'] as String,
            imagePath: storage.resolve(row['image'] as String),
            rows: row['rows'] as int,
            columns: row['columns'] as int,
            createdAt: DateTime.parse(row['created'] as String),
            placed: placements
                .where((entry) => entry['puzzle_id'] == row['id'])
                .map((entry) => entry['cell'] as int)
                .toSet(),
          ),
        )
        .toList();
  }

  Future<Puzzle> create({
    required String name,
    required Uint8List reference,
    required int rows,
    required int columns,
  }) async {
    if (name.trim().isEmpty ||
        rows < 2 ||
        columns < 2 ||
        rows > 100 ||
        columns > 100) {
      throw ArgumentError('Enter a puzzle name and 2–100 rows and columns.');
    }
    final now = DateTime.now().toUtc();
    final id = now.microsecondsSinceEpoch.toString();
    final filename = '$id.jpg';
    final path = storage.resolve(filename);
    await storage.write(path, reference);
    try {
      await db.insert('puzzles', {
        'id': id,
        'name': name.trim(),
        'image': filename,
        'rows': rows,
        'columns': columns,
        'created': now.toIso8601String(),
      });
    } catch (_) {
      await storage.delete(path);
      rethrow;
    }
    return Puzzle(
      id: id,
      name: name.trim(),
      imagePath: path,
      rows: rows,
      columns: columns,
      createdAt: now,
    );
  }

  Future<void> setPlaced(Puzzle puzzle, int cell, bool placed) async {
    if (cell < 0 || cell >= puzzle.count) {
      throw RangeError.range(cell, 0, puzzle.count - 1);
    }
    if (placed) {
      await db.insert('placements', {
        'puzzle_id': puzzle.id,
        'cell': cell,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete(
        'placements',
        where: 'puzzle_id = ? AND cell = ?',
        whereArgs: [puzzle.id, cell],
      );
    }
  }

  Future<void> saveScan(
    Puzzle puzzle,
    ScanResult result, {
    DateTime? now,
  }) async {
    await db.insert('scans', {
      'puzzle_id': puzzle.id,
      'created': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'candidates': jsonEncode(
        result.candidates.map((c) => c.toJson()).toList(),
      ),
      'low_texture': result.lowTexture ? 1 : 0,
      'elapsed_ms': result.elapsedMs,
    });
  }

  Future<List<ScanResult>> history(Puzzle puzzle) async {
    final records = await db.query(
      'scans',
      where: 'puzzle_id = ?',
      whereArgs: [puzzle.id],
      orderBy: 'id DESC',
      limit: 50,
    );
    return records
        .map(
          (record) => ScanResult(
            candidates: (jsonDecode(record['candidates'] as String) as List)
                .map(
                  (entry) => Candidate.fromJson(entry as Map<String, dynamic>),
                )
                .toList(),
            lowTexture: record['low_texture'] == 1,
            elapsedMs: record['elapsed_ms'] as int,
          ),
        )
        .toList();
  }

  Future<void> delete(Puzzle puzzle) async {
    await db.delete('puzzles', where: 'id = ?', whereArgs: [puzzle.id]);
    await storage.delete(puzzle.imagePath);
  }
}
