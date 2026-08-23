import 'package:flutter/material.dart';

import '../categories/manage_categories_screen.dart';
import '../currencies/manage_currencies_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currencies'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageCurrenciesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.cloud_outlined),
            title: Text('Backup & Restore'),
            subtitle: Text('Coming in Phase 4 — Google Drive backup'),
          ),
        ],
      ),
    );
  }
}
