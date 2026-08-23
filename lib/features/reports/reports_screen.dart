import 'package:flutter/material.dart';

/// Placeholder for Phase 3 — per-account/currency totals, in-vs-out, and
/// category breakdown with a period filter (see the implementation plan).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Reports are coming in Phase 3.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
