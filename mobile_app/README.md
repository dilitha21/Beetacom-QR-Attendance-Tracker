# Flutter Mobile App Foundation

This folder contains the offline student-registration foundation for the admin-only attendance app.

## What is included

- `sqflite` local storage setup
- `Students` table
- `LocalAttendance` table
- Student registration screen
- Unique student ID generation in the form `STD-948274`

## Files

- `lib/main.dart` boots the app
- `lib/database/app_database.dart` initializes SQLite and handles inserts
- `lib/screens/student_registration_screen.dart` contains the registration UI

## Notes

This is the app foundation only. QR generation and scanner logic are intentionally not included yet.

If you want to run this as a full Flutter project, create the standard platform folders with `flutter create` and then copy these files into the generated project, or let me scaffold the platform-specific files next.