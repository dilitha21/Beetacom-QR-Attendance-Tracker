# QR-Attendance-App

Monorepo for the offline-first QR attendance system.

## Backend

Lightweight Node.js + Express API backed by a local SQLite database file.

## Mobile App

Flutter app in [mobile_app](mobile_app) with offline local storage, student registration, scanner, manual entry, and sync logic.

## Requirements

- Node.js 18 or newer
- npm

## Install

```bash
npm install
```

## Run

```bash
npm start
```

Development mode with automatic restart support from Node:

```bash
npm run dev
```

## Database

The SQLite database is created automatically at:

```text
data/attendance.db
```

## API

### `POST /api/sync-attendance`

Request body:

```json
{
  "attendanceRecords": [
    {
      "unique_student_id": "STU-001",
      "timestamp": "2026-07-16T09:00:00.000Z",
      "sync_status": "synced"
    }
  ]
}
```

Response:

```json
{
  "message": "Attendance synced successfully",
  "insertedCount": 1,
  "inserted": ["STU-001"]
}
```

### `GET /health`

Returns server status and the database path.