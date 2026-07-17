import 'dart:math';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/student.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String _databaseName = 'attendance_mobile.db';
  static const int _databaseVersion = 4;

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
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Present',
        sync_status TEXT NOT NULL DEFAULT 'pending',
        class_name TEXT,
        time_slot TEXT,
        date TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE Students ADD COLUMN photo_url TEXT');
      await db.execute("ALTER TABLE LocalAttendance ADD COLUMN status TEXT NOT NULL DEFAULT 'Present'");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE LocalAttendance ADD COLUMN class_name TEXT");
      await db.execute("ALTER TABLE LocalAttendance ADD COLUMN time_slot TEXT");
      await db.execute("ALTER TABLE LocalAttendance ADD COLUMN date TEXT");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE Students RENAME COLUMN grade TO student_index");
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

  Future<int> markStudentPresent(String uniqueStudentId, {DateTime? timestamp, String? className, String? timeSlot, String? date}) async {
    final db = await database;
    return db.insert('LocalAttendance', {
      'unique_student_id': uniqueStudentId,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      'status': 'Present',
      'sync_status': 'pending',
      'class_name': className,
      'time_slot': timeSlot,
      'date': date,
    });
  }

  Future<List<Map<String, Object?>>> getUnsyncedAttendanceRecords() async {
    final db = await database;
    return db.query(
      'LocalAttendance',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
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
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<bool> hasAttendanceForDay(String uniqueStudentId, DateTime day) async {
    final db = await database;
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await db.query(
      'LocalAttendance',
      columns: const ['id'],
      where: 'unique_student_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        uniqueStudentId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> getTodayAttendanceWithStudentNames() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return db.rawQuery('''
      SELECT
        LocalAttendance.id,
        LocalAttendance.unique_student_id,
        LocalAttendance.timestamp,
        LocalAttendance.status,
        LocalAttendance.sync_status,
        LocalAttendance.class_name,
        LocalAttendance.time_slot,
        LocalAttendance.date,
        Students.name,
        Students.photo_url
      FROM LocalAttendance
      LEFT JOIN Students ON Students.unique_student_id = LocalAttendance.unique_student_id
      WHERE LocalAttendance.timestamp >= ? AND LocalAttendance.timestamp < ?
      ORDER BY LocalAttendance.timestamp DESC
    ''', [
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
    ]);
  }

  Future<List<Map<String, Object?>>> getFilteredAttendance(
    DateTime date, {
    String? className,
    String? timeSlot,
  }) async {
    final db = await database;
    
    final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    String whereClause = "((LocalAttendance.date = ?) OR (LocalAttendance.timestamp >= ? AND LocalAttendance.timestamp < ?))";
    List<Object?> whereArgs = [
      formattedDate,
      startOfDay.toIso8601String(),
      endOfDay.toIso8601String(),
    ];

    if (className != null && className.trim().isNotEmpty) {
      whereClause += " AND LocalAttendance.class_name = ?";
      whereArgs.add(className.trim());
    }

    if (timeSlot != null && timeSlot.trim().isNotEmpty && timeSlot != 'All') {
      whereClause += " AND LocalAttendance.time_slot = ?";
      whereArgs.add(timeSlot.trim());
    }

    return db.rawQuery('''
      SELECT
        LocalAttendance.id,
        LocalAttendance.unique_student_id,
        LocalAttendance.timestamp,
        LocalAttendance.status,
        LocalAttendance.sync_status,
        LocalAttendance.class_name,
        LocalAttendance.time_slot,
        LocalAttendance.date,
        Students.name,
        Students.photo_url
      FROM LocalAttendance
      LEFT JOIN Students ON Students.unique_student_id = LocalAttendance.unique_student_id
      WHERE $whereClause
      ORDER BY LocalAttendance.timestamp DESC
    ''', whereArgs);
  }
}
