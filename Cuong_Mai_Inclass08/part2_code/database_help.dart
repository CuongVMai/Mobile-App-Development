import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models/folder.dart';
import 'models/catalog_card.dart';

class DatabaseHelper {
  // Keep the Part I database name and location unchanged.
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE $table (
          $columnId INTEGER PRIMARY KEY,
          $columnName TEXT NOT NULL,
          $columnAge INTEGER NOT NULL
        )''');
        await _createCatalogTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCatalogTables(db);
      },
    );
  }

  Future<void> _createCatalogTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE folders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      suit TEXT NOT NULL CHECK(suit IN ('Hearts','Diamonds','Clubs','Spades')),
      notes TEXT NOT NULL DEFAULT '',
      image_ref TEXT,
      folder_id INTEGER NOT NULL,
      FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX idx_cards_folder_id ON cards(folder_id)');
  }

  // Original Part I API, retained so the old screen still works.
  Future<int> insert(Map<String, dynamic> row) => _db.insert(table, row);
  Future<List<Map<String, dynamic>>> queryAllRows() => _db.query(table);
  Future<int> queryRowCount() async =>
      Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
  Future<int> update(Map<String, dynamic> row) => _db.update(
    table, row, where: '$columnId = ?', whereArgs: [row[columnId]]);
  Future<int> delete(int id) => _db.delete(table,
    where: '$columnId = ?', whereArgs: [id]);

  Future<List<Folder>> getFoldersWithCounts() async {
    final rows = await _db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders f LEFT JOIN cards c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return rows.map(Folder.fromMap).toList();
  }

  Future<int> insertFolder(String name) => _db.insert('folders',
    Folder(name: name.trim(), createdAt: DateTime.now().toIso8601String()).toMap());

  Future<int> updateFolder(int id, String name) => _db.update(
    'folders', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteFolder(int id) => _db.delete(
    'folders', where: 'id = ?', whereArgs: [id]);

  Future<List<CatalogCard>> getCards(int folderId) async {
    final rows = await _db.query('cards', where: 'folder_id = ?',
      whereArgs: [folderId], orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(CatalogCard.fromMap).toList();
  }

  Future<int> insertCard(CatalogCard card) => _db.insert('cards', card.toMap());
  Future<int> updateCard(CatalogCard card) {
    if (card.id == null) throw ArgumentError('Card ID required for update');
    return _db.update('cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
  }
  Future<int> deleteCard(int id) => _db.delete('cards', where: 'id = ?', whereArgs: [id]);

  Future<bool> folderExists(int id) async =>
      (Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM folders WHERE id = ?', [id])) ?? 0) == 1;
}
