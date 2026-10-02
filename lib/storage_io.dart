import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class PuzzleStorage {
  PuzzleStorage(this.db, this.directory);
  final Database db;
  final String directory;
  static Future<PuzzleStorage> open(OnDatabaseCreateFn createSchema) async {
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
    return PuzzleStorage(db, directory.path);
  }

  String resolve(String filename) => p.join(directory, filename);
  Future<void> write(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List> read(String path) => File(path).readAsBytes();
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
