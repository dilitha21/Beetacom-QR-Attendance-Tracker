import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../database/app_database.dart';
import '../models/student.dart';
import '../services/attendance_sync_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualEntryController = TextEditingController();

  bool _isProcessing = false;
  bool _isSyncing = false;
  String? _lastScannedId;
  List<_AttendanceHistoryItem> _todayHistory = const [];

  @override
  void dispose() {
    _scannerController.dispose();
    _manualEntryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTodayHistory();
  }

  Future<void> _loadTodayHistory() async {
    final rows = await AppDatabase.instance.getTodayAttendanceWithStudentNames();
    if (!mounted) {
      return;
    }

    setState(() {
      _todayHistory = rows.map(_AttendanceHistoryItem.fromMap).toList();
    });
  }

  Future<void> _syncPendingAttendance() async {
    if (_isSyncing) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await AttendanceSyncService.syncPendingAttendance();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      if (result.success) {
        await _loadTodayHistory();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _handleSubmittedId(String rawValue, {required String source}) async {
    final uniqueStudentId = rawValue.trim();

    if (uniqueStudentId.isEmpty || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedId = uniqueStudentId;
    });

    await _scannerController.stop();

    try {
      final student = await AppDatabase.instance.findStudentByUniqueId(uniqueStudentId);

      if (student == null) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No student found for ID $uniqueStudentId')),
        );
        return;
      }

      final alreadyMarkedToday = await AppDatabase.instance.hasAttendanceForDay(uniqueStudentId, DateTime.now());
      if (alreadyMarkedToday) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} is already marked present today.')),
        );
        return;
      }

      await AppDatabase.instance.markStudentPresent(uniqueStudentId);
      await _loadTodayHistory();

      if (!mounted) {
        return;
      }

      _manualEntryController.clear();

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StudentVerificationAvatar(student: student),
                  const SizedBox(height: 20),
                  Text(
                    student.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Marked Present via ${source.toLowerCase()}.\nID: ${student.uniqueStudentId}',
                    textAlign: TextAlign.center,
                    style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF0F766E),
                    ),
                    child: const Text('Continue Scanning'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark attendance: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      await _scannerController.start();
    }
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isProcessing) {
      return;
    }

    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) {
      return;
    }

    _handleSubmittedId(rawValue, source: 'scan');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sync pending attendance',
            onPressed: _isSyncing ? null : _syncPendingAttendance,
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07111F), Color(0xFF134E4A), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: Colors.white.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Live QR Scanner',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan the student QR or enter the ID manually if the code is damaged.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 16),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: _handleBarcodeCapture,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isProcessing
                            ? 'Verifying student...'
                            : 'Ready to scan${_lastScannedId != null ? ' ($_lastScannedId)' : ''}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F766E),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Manual Entry',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _manualEntryController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Type unique student ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        onSubmitted: (value) => _handleSubmittedId(value, source: 'manual entry'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _handleSubmittedId(
                                  _manualEntryController.text,
                                  source: 'manual entry',
                                ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark Present'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF134E4A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _syncPendingAttendance,
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: const Text('Sync Pending Attendance'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: Color(0xFF134E4A)),
                          foregroundColor: const Color(0xFF134E4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.white.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, color: Color(0xFF134E4A)),
                          const SizedBox(width: 8),
                          Text(
                            'Today\'s Attendance',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_todayHistory.isEmpty)
                        Text(
                          'No attendance has been recorded yet today.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        )
                      else
                        ..._todayHistory.take(12).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF0F766E),
                                    child: Text(
                                      item.initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.uniqueStudentId} • ${item.status}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.black54,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    item.shortTime,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF134E4A),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentVerificationAvatar extends StatelessWidget {
  const _StudentVerificationAvatar({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final photoUrl = student.photoUrl;

    Widget avatar;
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Image.network(
          photoUrl,
          width: 156,
          height: 156,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    } else {
      avatar = _fallbackAvatar();
    }

    return avatar;
  }

  Widget _fallbackAvatar() {
    final initials = student.name.trim().isEmpty
        ? 'S'
        : student.name.trim().split(RegExp(r'\s+')).take(2).map((word) => word.characters.first).join();

    return CircleAvatar(
      radius: 78,
      backgroundColor: const Color(0xFF0F766E),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AttendanceHistoryItem {
  final int? id;
  final String uniqueStudentId;
  final String timestamp;
  final String status;
  final String syncStatus;
  final String name;
  final String? photoUrl;

  const _AttendanceHistoryItem({
    required this.id,
    required this.uniqueStudentId,
    required this.timestamp,
    required this.status,
    required this.syncStatus,
    required this.name,
    required this.photoUrl,
  });

  factory _AttendanceHistoryItem.fromMap(Map<String, Object?> map) {
    return _AttendanceHistoryItem(
      id: map['id'] as int?,
      uniqueStudentId: map['unique_student_id'] as String,
      timestamp: map['timestamp'] as String,
      status: map['status'] as String,
      syncStatus: map['sync_status'] as String,
      name: (map['name'] as String?) ?? 'Unknown Student',
      photoUrl: map['photo_url'] as String?,
    );
  }

  String get shortTime {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed == null) {
      return timestamp;
    }

    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) {
      return 'S';
    }

    final buffer = StringBuffer();
    for (final word in words.take(2)) {
      buffer.write(word.characters.first);
    }
    return buffer.toString().toUpperCase();
  }
}