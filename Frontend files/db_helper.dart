import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Local SQLite helper for MealMind user data persistence.
/// All numeric fields (age, weight, height) are stored as TEXT
/// to preserve user-entered formatting (e.g. units, decimals).
class DBHelper {
  static Database? _database;

  // ----------------------------------------------------------
  // DATABASE INITIALISATION
  // ----------------------------------------------------------

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'user_data.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            email       TEXT PRIMARY KEY,
            appPassword TEXT,
            name        TEXT,
            age         TEXT,
            weight      TEXT,
            height      TEXT,
            gender      TEXT,
            budget      TEXT,
            condition   TEXT,
            allergies   TEXT,
            goal        TEXT,
            weightChange TEXT,
            country     TEXT,
            diet_type   TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migrations are additive only; downgrade not supported.
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN gender TEXT;');
          await db.execute('ALTER TABLE users ADD COLUMN budget TEXT;');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE users ADD COLUMN diet_type TEXT;');
        }
      },
    );
  }

  // ----------------------------------------------------------
  // AUTHENTICATION
  // ----------------------------------------------------------

  /// Inserts or replaces the user row with login credentials.
  static Future<void> saveUser(String email, String password) async {
    try {
      final db = await database;
      await db.insert(
        'users',
        {'email': email, 'appPassword': password},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('DBHelper.saveUser failed: $e');
    }
  }

  /// Returns the stored app password for [email], or null if not found.
  static Future<String?> getAppPassword(String email) async {
    try {
      final db = await database;
      final rows = await db.query(
        'users',
        columns: ['appPassword'],
        where: 'email = ?',
        whereArgs: [email],
      );
      return rows.isNotEmpty ? rows.first['appPassword'] as String? : null;
    } catch (e) {
      throw Exception('DBHelper.getAppPassword failed: $e');
    }
  }

  // ----------------------------------------------------------
  // USER PROFILE
  // ----------------------------------------------------------

  /// Upserts the full user profile for [email].
  /// Uses INSERT … ON CONFLICT REPLACE so the row is created if absent.
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
    try {
      final db = await database;
      await db.insert(
        'users',
        {
          'email':       email,
          'name':        name,
          'age':         age,
          'weight':      weight,
          'height':      height,
          'gender':      gender,
          'budget':      budget,
          'condition':   condition,
          'allergies':   allergies,
          'goal':        goal,
          'weightChange': weightChange,
          'country':     country,
          'diet_type':   dietType,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('DBHelper.saveUserInfo failed: $e');
    }
  }

  /// Returns all profile fields for [email], or null if no record exists.
  static Future<Map<String, dynamic>?> getUserInfo(String email) async {
    try {
      final db = await database;
      final rows = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      return rows.isNotEmpty ? rows.first : null;
    } catch (e) {
      throw Exception('DBHelper.getUserInfo failed: $e');
    }
  }

  // ----------------------------------------------------------
  // CLEANUP
  // ----------------------------------------------------------

  /// Closes the database connection and resets the cached instance.
  static Future<void> closeDB() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}


