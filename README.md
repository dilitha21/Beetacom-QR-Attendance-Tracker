# Beetacom-QR-Attendance-Tracker

An offline-first, admin-only QR Attendance Tracking System.

## Features

- **Session Setup**: Configure specific classes, dates, and time slots before beginning a session.
- **QR Scanner**: Fast mobile QR scanning to mark students present instantly.
- **Anti-Fraud Verification**: Instantly displays student's photo and details upon successful scan for visual confirmation.
- **Manual Entry Fallback**: Supports typing the student's index manually if their QR card is unreadable.
- **Offline First**: All attendance is marked locally via SQLite, allowing completely offline operation.
- **Attendance Dashboard**: View real-time, filterable offline attendance records locally.
- **Sync Engine**: Automatically synchronizes pending attendance records to the central backend when internet is restored.

## Technologies Used

### Mobile App (Admin Client)
- **Flutter** (Dart)
- **SQLite** (`sqflite`) for robust offline data storage
- **Mobile Scanner** for fast QR code detection

### Central Backend
- **Node.js & Express.js**
- **SQLite** (`better-sqlite3`) for lightweight central storage
- **Custom Retry Logic** to handle concurrent write locks in SQLite