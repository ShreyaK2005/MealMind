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
      version: 3, // version bump for schema update
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            email TEXT PRIMARY KEY,
            appPassword TEXT,
            name TEXT,
            age TEXT,
            weight TEXT,
            height TEXT,
            gender TEXT,
            budget TEXT,
            condition TEXT,
            allergies TEXT,
            goal TEXT,
            weightChange TEXT,
            country TEXT,
            diet_type TEXT
          )
        ''');
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE users ADD COLUMN gender TEXT;");
          await db.execute("ALTER TABLE users ADD COLUMN budget TEXT;");
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE users ADD COLUMN diet_type TEXT;");
        }
      },
    );
  }

  // ----------------------------------------------------------
  // SAVE LOGIN CREDENTIALS (email + app password)
  // ----------------------------------------------------------
  static Future<void> saveUser(String email, String password) async {
    final db = await database;

    await db.insert(
      'users',
      {
        'email': email,
        'appPassword': password,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ----------------------------------------------------------
  // SAVE/UPDATE COMPLETE USER INFO INCLUDING diet_type
  // ----------------------------------------------------------
  static Future<void> saveUserInfo({
    required String email,
    required String name,
    required String age,
    required String weight,
    required String height,
    required String gender,
    required String budget,
    required String condition,
    required String allergies,
    required String goal,
    required String weightChange,
    required String country,
    required String dietType,
  }) async {
    final db = await database;

    await db.update(
      'users',
      {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'budget': budget,
        'condition': condition,
        'allergies': allergies,
        'goal': goal,
        'weightChange': weightChange,
        'country': country,
        'diet_type': dietType,
      },
      where: 'email = ?',
      whereArgs: [email],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ----------------------------------------------------------
  // LOAD ALL FIELDS FOR USER INFO PAGE
  // ----------------------------------------------------------
  static Future<Map<String, dynamic>?> getUserInfo(String email) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    return result.isNotEmpty ? result.first : null;
  }

  // ----------------------------------------------------------
  // GET ONLY APP PASSWORD DURING LOGIN
  // ----------------------------------------------------------
  static Future<String?> getAppPassword(String email) async {
    final db = await database;

    final result = await db.query(
      'users',
      columns: ['appPassword'],
      where: 'email = ?',
      whereArgs: [email],
    );

    return result.isNotEmpty ? result.first['appPassword'] as String : null;
  }
}

