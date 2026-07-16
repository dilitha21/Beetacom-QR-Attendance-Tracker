const express = require('express');
const { dbPath, insertAttendanceRecords, runWithRetry } = require('./db');

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json({ limit: '1mb' }));

app.get('/health', (_request, response) => {
  response.json({ ok: true, dbPath });
});

app.post('/api/sync-attendance', async (request, response) => {
  const attendanceRecords = Array.isArray(request.body)
    ? request.body
    : request.body?.attendanceRecords;

  if (!Array.isArray(attendanceRecords)) {
    return response.status(400).json({
      error: 'attendanceRecords must be an array',
    });
  }

  try {
    for (const record of attendanceRecords) {
      if (!record || typeof record.unique_student_id !== 'string' || typeof record.timestamp !== 'string') {
        return response.status(400).json({
          error: 'Each record must include unique_student_id and timestamp',
        });
      }
    }

    await runWithRetry(() => insertAttendanceRecords(attendanceRecords));

    return response.status(201).json({
      message: 'Attendance synced successfully',
      insertedCount: attendanceRecords.length,
      inserted: attendanceRecords.map((record) => record.unique_student_id),
    });
  } catch (error) {
    return response.status(500).json({
      error: 'Failed to sync attendance',
      details: error.message,
    });
  }
});

app.listen(port, () => {
  console.log(`Attendance API running on http://localhost:${port}`);
  console.log(`SQLite database: ${dbPath}`);
});