const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const dataDir = path.join(__dirname, '..', 'data');
const dbPath = path.join(dataDir, 'attendance.db');

fs.mkdirSync(dataDir, { recursive: true });

const db = new Database(dbPath);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS Students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_student_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    grade TEXT,
    contact TEXT,
    photo_url TEXT
  );

  CREATE TABLE IF NOT EXISTS Attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    unique_student_id TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'synced'
  );
`);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isSqliteBusyError(error) {
  return error && typeof error.code === 'string' && (error.code === 'SQLITE_BUSY' || error.code === 'SQLITE_LOCKED');
}

async function runWithRetry(operation, { retries = 10, delayMs = 2000 } = {}) {
  let attempt = 0;

  while (true) {
    try {
      return operation();
    } catch (error) {
      if (!isSqliteBusyError(error) || attempt >= retries) {
        throw error;
      }

      attempt += 1;
      await sleep(delayMs);
    }
  }
}

function insertAttendanceRecord(record) {
  const statement = db.prepare(`
    INSERT INTO Attendance (unique_student_id, timestamp, sync_status)
    VALUES (?, ?, ?)
  `);

  return statement.run(record.unique_student_id, record.timestamp, record.sync_status ?? 'synced');
}

const insertAttendanceRecords = db.transaction((records) => {
  for (const record of records) {
    insertAttendanceRecord(record);
  }
});

module.exports = {
  db,
  dbPath,
  insertAttendanceRecords,
  insertAttendanceRecord,
  runWithRetry,
};