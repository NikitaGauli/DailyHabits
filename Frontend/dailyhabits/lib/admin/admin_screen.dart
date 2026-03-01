// =============================================================================
// File: admin_screen.dart
// Description: Entry point widget for the Admin Dashboard. Wraps the AdminShell
//              in an AdminController provider so it has its own state scope.
//              Navigate here from the main app via Navigator.push.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/admin/controllers/admin_controller.dart';
import 'package:dailyhabits/admin/admin_shell.dart';

/// Launches the admin dashboard.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const AdminScreen()),
/// );
/// ```
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminController(),
      child: const AdminShell(),
    );
  }
}
