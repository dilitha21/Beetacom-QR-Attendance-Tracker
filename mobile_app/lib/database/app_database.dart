import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/student.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String _databaseName = 'attendance_mobile.db';
  static const int _databaseVersion = 5;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_student_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        student_index TEXT NOT NULL,
        contact TEXT NOT NULL,
        photo_url TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE LocalAttendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        UNIQUE(unique_student_id, date)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE Students ADD COLUMN photo_url TEXT');
    }
    if (oldVersion < 4) {
      // Handle the rename that was in version 4 if oldVersion is < 4
      try {
        await db.execute("ALTER TABLE Students RENAME COLUMN grade TO student_index");
      } catch (_) {}
    }
    if (oldVersion < 5) {
      await db.execute('DROP TABLE IF EXISTS LocalAttendance');
      await db.execute('''
        CREATE TABLE LocalAttendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unique_student_id TEXT NOT NULL,
          date TEXT NOT NULL,
          check_in_time TEXT,
          check_out_time TEXT,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          UNIQUE(unique_student_id, date)
        )
      ''');
    }
  }

  Future<String> generateUniqueStudentId() async {
    final db = await database;
    final random = Random.secure();

    while (true) {
      final suffix = List.generate(6, (_) => random.nextInt(10)).join();
      final candidate = 'STD-$suffix';
      final existing = await db.query(
        'Students',
        columns: const ['id'],
        where: 'unique_student_id = ?',
        whereArgs: [candidate],
        limit: 1,
      );

      if (existing.isEmpty) {
        return candidate;
      }
    }
  }

  Future<int> insertStudent(Student student) async {
    final db = await database;
    return db.insert('Students', student.toMap());
  }

  Future<Student?> findStudentByUniqueId(String uniqueStudentId) async {
    final db = await database;
    final rows = await db.query(
      'Students',
      where: 'unique_student_id = ?',
      whereArgs: [uniqueStudentId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Student.fromMap(rows.first);
  }

  Future<String> recordAttendance(String uniqueStudentId) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timestampStr = now.toIso8601String();

    final existing = await db.query(
      'LocalAttendance',
      where: 'unique_student_id = ? AND date = ?',
      whereArgs: [uniqueStudentId, dateStr],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Check in
      await db.insert('LocalAttendance', {
        'unique_student_id': uniqueStudentId,
        'date': dateStr,
        'check_in_time': timestampStr,
        'sync_status': 'pending',
      });
      return 'check_in';
    } else {
      // Check out
      await db.update(
        'LocalAttendance',
        {
          'check_out_time': timestampStr,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return 'check_out';
    }
  }

  Future<List<Map<String, Object?>>> getUnsyncedAttendanceRecords() async {
    final db = await database;
    return db.query(
      'LocalAttendance',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
  }

  Future<int> markAttendanceRecordsSynced(List<int> ids) async {
    if (ids.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.update(
      'LocalAttendance',
      {'sync_status': 'synced'},
      where: "id IN (${List.filled(ids.length, '?').join(',')})",
      whereArgs: ids,
    );
  }

  Future<bool> hasAttendanceForDay(String uniqueStudentId, DateTime day) async {
    final db = await database;
    final dateStr = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    
    final rows = await db.query(
      'LocalAttendance',
      columns: const ['id'],
      where: 'unique_student_id = ? AND date = ?',
      whereArgs: [uniqueStudentId, dateStr],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> getTodayAttendanceWithStudentNames() async {
    final db = await database;
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return db.rawQuery('''
      SELECT
        LocalAttendance.id,
        LocalAttendance.unique_student_id,
        LocalAttendance.date,
        LocalAttendance.check_in_time,
        LocalAttendance.check_out_time,
        LocalAttendance.sync_status,
        Students.name,
        Students.photo_url
      FROM LocalAttendance
      LEFT JOIN Students ON Students.unique_student_id = LocalAttendance.unique_student_id
      WHERE LocalAttendance.date = ?
      ORDER BY COALESCE(LocalAttendance.check_out_time, LocalAttendance.check_in_time) DESC
    ''', [dateStr]);
  }

  Future<List<Map<String, Object?>>> getFilteredAttendance(
    DateTime date,
  ) async {
    final db = await database;
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    return db.rawQuery('''
      SELECT
        LocalAttendance.id,
        LocalAttendance.unique_student_id,
        LocalAttendance.date,
        LocalAttendance.check_in_time,
        LocalAttendance.check_out_time,
        LocalAttendance.sync_status,
        Students.name,
        Students.photo_url
      FROM LocalAttendance
      LEFT JOIN Students ON Students.unique_student_id = LocalAttendance.unique_student_id
      WHERE LocalAttendance.date = ?
      ORDER BY COALESCE(LocalAttendance.check_out_time, LocalAttendance.check_in_time) DESC
    ''', [formattedDate]);
  }
}
