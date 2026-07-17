import 'package:flutter/material.dart';
import 'scanner_screen.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  final TextEditingController _classNameController = TextEditingController();
  String _selectedTimeSlot = 'Morning (08:00 AM - 12:00 PM)';

  final List<String> _timeSlots = [
    'Morning (08:00 AM - 12:00 PM)',
    'Afternoon (12:00 PM - 04:00 PM)',
    'Evening (04:00 PM - 08:00 PM)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _classNameController.dispose();
    super.dispose();
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
    }
  }

  void _startScanning() {
    if (_formKey.currentState!.validate()) {
      final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScannerScreen(
            className: _classNameController.text.trim(),
            timeSlot: _selectedTimeSlot,
            date: formattedDate,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Setup'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Configure Session',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set the details for this attendance session before scanning.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                
                // Date Picker
                InkWell(
                  onTap: () => _pickDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Class Name Field
                TextFormField(
                  controller: _classNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Class Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a class name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Time Slot Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedTimeSlot,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Time Slot',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                    filled: true,
                    fillColor: Colors.white10,
                  ),
                  items: _timeSlots.map((String slot) {
                    return DropdownMenuItem<String>(
                      value: slot,
                      child: Text(slot),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTimeSlot = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 40),

                // Start Scanning Button
                FilledButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'Start Scanning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
