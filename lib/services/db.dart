import 'package:exchangilymobileapp/models/wallet.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DataBaseService {
  static final _databaseName = 'wallet_database.db';
  static final _databaseVersion = 1;
  var databasePath;
  String path;
  Future<Database> database;

  openDb() async {
    databasePath = await getDatabasesPath();
    path = join(databasePath, 'test_databse.db');
    database = openDatabase(path, onCreate: (db, version) {
      return db.execute(
          "CREATE TABLE test(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)");
    }, version: 1);
  }

  Future onCreate(Database db, int version) async {
    //await db.execute(sql)
  }

  deleteDb() async {
    await deleteDatabase(path);
  }

  closeDb() async {}

  Future<void> insertTest(Test test) async {
    final Database db = await database;

    await db.insert('test', test.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
