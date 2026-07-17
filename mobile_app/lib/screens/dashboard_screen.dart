import 'package:flutter/material.dart';
import '../database/app_database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedClassName = '';
  String _selectedTimeSlot = 'All';

  final List<String> _timeSlots = [
    'All',
    'Morning (08:00 AM - 12:00 PM)',
    'Afternoon (12:00 PM - 04:00 PM)',
    'Evening (04:00 PM - 08:00 PM)',
  ];

  List<Map<String, Object?>> _records = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final rows = await AppDatabase.instance.getFilteredAttendance(
      _selectedDate,
      className: _selectedClassName.isEmpty ? null : _selectedClassName,
      timeSlot: _selectedTimeSlot == 'All' ? null : _selectedTimeSlot,
    );

    if (mounted) {
      setState(() {
        _records = rows;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Dashboard'),
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today, size: 20),
                              filled: true,
                              fillColor: Colors.black26,
                              isDense: true,
                            ),
                            child: Text(
                              formattedDate,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedTimeSlot,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Time Slot',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.black26,
                            isDense: true,
                          ),
                          items: _timeSlots.map((String slot) {
                            return DropdownMenuItem<String>(
                              value: slot,
                              child: Text(slot, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedTimeSlot = newValue!;
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Class Name Filter (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: Colors.black26,
                      isDense: true,
                    ),
                    onChanged: (value) {
                      _selectedClassName = value;
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Total Present: ${_records.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? const Center(
                          child: Text(
                            'No records found.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            final name = record['name']?.toString() ?? 'Unknown Student';
                            final uniqueId = record['unique_student_id']?.toString() ?? 'Unknown ID';
                            final timeSlot = record['time_slot']?.toString() ?? 'Unknown Slot';
                            final className = record['class_name']?.toString() ?? 'N/A';
                            final timestampStr = record['timestamp']?.toString() ?? '';
                            final syncStatus = record['sync_status']?.toString() ?? 'pending';

                            DateTime? time;
                            if (timestampStr.isNotEmpty) {
                              time = DateTime.tryParse(timestampStr);
                            }

                            final timeString = time != null
                                ? "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"
                                : 'Unknown Time';

                            return Card(
                              color: Colors.white10,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueAccent,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '$uniqueId • $className\n$timeSlot',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                isThreeLine: true,
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      timeString,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Icon(
                                      syncStatus == 'synced' ? Icons.cloud_done : Icons.cloud_upload,
                                      size: 16,
                                      color: syncStatus == 'synced' ? Colors.green : Colors.orange,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
