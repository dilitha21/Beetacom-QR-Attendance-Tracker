import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../database/app_database.dart';

class AttendanceSyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  const AttendanceSyncResult({
    required this.success,
    required this.syncedCount,
    required this.message,
  });
}

class AttendanceSyncService {
  AttendanceSyncService._();

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static Future<bool> hasActiveInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$backendBaseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<AttendanceSyncResult> syncPendingAttendance() async {
    final hasConnection = await hasActiveInternetConnection();
    if (!hasConnection) {
      return const AttendanceSyncResult(
        success: false,
        syncedCount: 0,
        message: 'No active connection available for sync.',
      );
    }

    final pendingRows = await AppDatabase.instance.getUnsyncedAttendanceRecords();
    if (pendingRows.isEmpty) {
      return const AttendanceSyncResult(
        success: true,
        syncedCount: 0,
        message: 'No pending attendance records to sync.',
      );
    }

    final payload = pendingRows
        .map(
          (row) => {
            'unique_student_id': row['unique_student_id'],
            'date': row['date'],
            'check_in_time': row['check_in_time'],
            'check_out_time': row['check_out_time'],
          },
        )
        .toList();

    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/sync-attendance'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AttendanceSyncResult(
          success: false,
          syncedCount: 0,
          message: 'Backend rejected the sync request (${response.statusCode}).',
        );
      }

      final decodedBody = jsonDecode(response.body);
      final message = decodedBody is Map<String, dynamic> ? decodedBody['message']?.toString() ?? '' : '';
      final isSuccessMessage = message.toLowerCase().contains('completed') || message.toLowerCase().contains('success');

      if (!isSuccessMessage) {
        return AttendanceSyncResult(
          success: false,
          syncedCount: 0,
          message: message.isEmpty ? 'Backend did not return a success message.' : message,
        );
      }

      final syncedIds = <int>[];
      for (final row in pendingRows) {
        final id = row['id'] as int?;
        if (id != null) {
          syncedIds.add(id);
        }
      }

      await AppDatabase.instance.markAttendanceRecordsSynced(syncedIds);

      return AttendanceSyncResult(
        success: true,
        syncedCount: syncedIds.length,
        message: 'Successfully synced ${syncedIds.length} records.',
      );
    } catch (error) {
      return AttendanceSyncResult(
        success: false,
        syncedCount: 0,
        message: 'Sync failed: $error',
      );
    }
  }
}
