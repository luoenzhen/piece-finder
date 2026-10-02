import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Browser SQLite persists both metadata and photo bytes in IndexedDB.
class PuzzleStorage {
  PuzzleStorage(this.db, this.directory);
  final Database db;
  final String directory;
  static Future<PuzzleStorage> open(OnDatabaseCreateFn createSchema) async {
    final db = await databaseFactoryFfiWeb.openDatabase(
      'piecefinder.db',
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await createSchema(db, version);
          await db.execute(
            'CREATE TABLE image_files (path TEXT PRIMARY KEY, bytes BLOB NOT NULL)',
          );
        },
      ),
    );
    return PuzzleStorage(db, 'browser');
  }

  String resolve(String filename) => filename;
  Future<void> write(String path, Uint8List bytes) async {
    await db.insert('image_files', {'path': path, 'bytes': bytes});
  }

  Future<Uint8List> read(String path) async {
    final records = await db.query(
      'image_files',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (records.isEmpty) throw StateError('Reference image unavailable');
    return Uint8List.fromList(records.single['bytes'] as List<int>);
  }

  Future<void> delete(String path) async {
    await db.delete('image_files', where: 'path = ?', whereArgs: [path]);
  }
}
