import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'user_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            email TEXT PRIMARY KEY,
            appPassword TEXT,
            name TEXT,
            age TEXT,
            weight TEXT,
            height TEXT,
            condition TEXT,
            allergies TEXT,
            goal TEXT,
            weightChange TEXT,
            country TEXT
          )
        ''');
      },
    );
  }

  static Future<void> saveUser(String email, String password) async {
    final db = await database;
    await db.insert(
      'users',
      {'email': email, 'appPassword': password},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> saveUserInfo({
    required String email,
    required String name,
    required String age,
    required String weight,
    required String height,
    required String condition,
    required String allergies,
    required String goal,
    required String weightChange,
    required String country,
  }) async {
    final db = await database;
    await db.update(
      'users',
      {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'condition': condition,
        'allergies': allergies,
        'goal': goal,
        'weightChange': weightChange,
        'country': country,
      },
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  static Future<Map<String, dynamic>?> getUserInfo(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  static Future<String?> getAppPassword(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      columns: ['appPassword'],
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first['appPassword'] as String : null;
  }
}



