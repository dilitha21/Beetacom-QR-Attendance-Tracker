import 'package:flutter/material.dart';

import 'scanner_screen.dart';
import 'student_registration_screen.dart';
import 'dashboard_screen.dart';

class AttendanceShell extends StatefulWidget {
  const AttendanceShell({super.key});

  @override
  State<AttendanceShell> createState() => _AttendanceShellState();
}

class _AttendanceShellState extends State<AttendanceShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    ScannerScreen(),
    StudentRegistrationScreen(),
    DashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_alt_1),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
