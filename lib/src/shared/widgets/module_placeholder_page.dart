import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({
    required this.title,
    required this.sourcePages,
    super.key,
  });

  final String title;
  final List<String> sourcePages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const Text('待迁移', style: TextStyle(color: AppTheme.brand)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final page in sourcePages)
            Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.description_outlined),
                title: Text(page),
              ),
            ),
        ],
      ),
    );
  }
}
