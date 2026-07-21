const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;
const DB_PATH = path.join(__dirname, 'database.sqlite');

// Initialize SQLite Database
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error('Error connecting to the database:', err.message);
  } else {
    console.log('Connected to the SQLite database.');
    initializeDatabase();
  }
});

function initializeDatabase() {
  db.serialize(() => {
    // Create Students table
    db.run(`
      CREATE TABLE IF NOT EXISTS Students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_student_id TEXT UNIQUE NOT NULL,
        name TEXT,
        grade TEXT,
        contact TEXT,
        photo_url TEXT
      )
    `);

    // Create Attendance table
    db.run(`
      CREATE TABLE IF NOT EXISTS Attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unique_student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        sync_status TEXT DEFAULT 'synced',
        UNIQUE(unique_student_id, date)
      )
    `);
    console.log('Database tables initialized.');
  });
}

// Utility function to execute a query with retry logic
function runQueryWithRetry(query, params, maxRetries = 5, retryDelayMs = 2000) {
  return new Promise((resolve, reject) => {
    const attemptQuery = (attempt) => {
      db.run(query, params, function (err) {
        if (err) {
          // If database is locked/busy, retry
          if (err.code === 'SQLITE_BUSY' || err.code === 'SQLITE_LOCKED') {
            if (attempt < maxRetries) {
              console.warn(`Database busy (SQLITE_BUSY). Retrying attempt ${attempt + 1}/${maxRetries} in ${retryDelayMs}ms...`);
              setTimeout(() => attemptQuery(attempt + 1), retryDelayMs);
            } else {
              reject(new Error(`Max retries reached. Database is still busy: ${err.message}`));
            }
          } else {
            reject(err);
          }
        } else {
          resolve(this);
        }
      });
    };
    attemptQuery(0);
  });
}

// POST endpoint to sync attendance records
app.post('/api/sync-attendance', async (req, res) => {
  const records = req.body;

  if (!Array.isArray(records)) {
    return res.status(400).json({ error: 'Expected an array of attendance records.' });
  }

  const results = {
    successful: 0,
    failed: 0,
    errors: []
  };

  for (const record of records) {
    const { unique_student_id, date, check_in_time, check_out_time } = record;

    if (!unique_student_id || !date) {
      results.failed++;
      results.errors.push({ record, error: 'Missing unique_student_id or date.' });
      continue;
    }

    // Upsert query: insert new record or update existing one if (unique_student_id, date) already exists
    const query = `
      INSERT INTO Attendance (unique_student_id, date, check_in_time, check_out_time, sync_status)
      VALUES (?, ?, ?, ?, 'synced')
      ON CONFLICT(unique_student_id, date) DO UPDATE SET
        check_in_time = COALESCE(excluded.check_in_time, Attendance.check_in_time),
        check_out_time = COALESCE(excluded.check_out_time, Attendance.check_out_time),
        sync_status = 'synced'
    `;

    try {
      await runQueryWithRetry(query, [
        unique_student_id,
        date,
        check_in_time || null,
        check_out_time || null
      ]);
      results.successful++;
    } catch (err) {
      console.error('Failed to sync record:', err.message);
      results.failed++;
      results.errors.push({ record, error: err.message });
    }
  }

  res.json({
    message: 'Sync process completed.',
    results
  });
});

app.listen(PORT, () => {
  console.log(\`Server is running on http://localhost:\${PORT}\`);
});
