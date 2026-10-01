import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class PuzzleRepository {
  PuzzleRepository(this.db, this.directory);
  final Database db;
  final Directory directory;

  static Future<PuzzleRepository> open() async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'puzzles'),
    );
    await directory.create(recursive: true);
    final db = await openDatabase(
      p.join(directory.path, 'piecefinder.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: createSchema,
    );
    return PuzzleRepository(db, directory);
  }

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
    await db.execute(
      'CREATE TABLE quota (id INTEGER PRIMARY KEY CHECK(id = 1), started TEXT NOT NULL, used INTEGER NOT NULL)',
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
            imagePath: p.join(directory.path, row['image'] as String),
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
    final file = File(p.join(directory.path, filename));
    await file.writeAsBytes(reference, flush: true);
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
      await file.delete();
      rethrow;
    }
    return Puzzle(
      id: id,
      name: name.trim(),
      imagePath: file.path,
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

  Future<ScanQuota> quota({DateTime? now}) async {
    final records = await db.query('quota');
    return records.isEmpty
        ? ScanQuota(used: 0, startedAt: now ?? DateTime.now().toUtc())
        : ScanQuota(
            used: records.first['used'] as int,
            startedAt: DateTime.parse(records.first['started'] as String),
          );
  }

  /// Consume quota only after a successful scan. One transaction prevents races.
  Future<void> saveScan(
    Puzzle puzzle,
    ScanResult result, {
    DateTime? now,
  }) async {
    final instant = (now ?? DateTime.now()).toUtc();
    await db.transaction((tx) async {
      final records = await tx.query('quota');
      final current = records.isEmpty
          ? ScanQuota(used: 0, startedAt: instant)
          : ScanQuota(
              used: records.first['used'] as int,
              startedAt: DateTime.parse(records.first['started'] as String),
            );
      if (current.remaining(instant) == 0) {
        throw StateError(
          'All five free scans have been used. Your allowance resets 24 hours after the first scan.',
        );
      }
      await tx.insert('scans', {
        'puzzle_id': puzzle.id,
        'created': instant.toIso8601String(),
        'candidates': jsonEncode(
          result.candidates.map((c) => c.toJson()).toList(),
        ),
        'low_texture': result.lowTexture ? 1 : 0,
        'elapsed_ms': result.elapsedMs,
      });
      await tx.insert('quota', {
        'id': 1,
        'started': (current.expired(instant) ? instant : current.startedAt)
            .toIso8601String(),
        'used': current.expired(instant) ? 1 : current.used + 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final file = File(puzzle.imagePath);
    if (await file.exists()) await file.delete();
  }
}
