import 'package:flutter/material.dart';
import '../models/api_database.dart';
import 'main_menu_screen.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final List<ApiDatabase> databases;

  const DatabaseSelectionScreen({
    super.key,
    required this.databases,
  });

  @override
  State<DatabaseSelectionScreen> createState() => _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Veritabanı Seçiniz'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: widget.databases.length,
        itemBuilder: (context, index) {
          final database = widget.databases[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  database.kod,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                database.ad,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${database.id}'),
                  Text('Program ID: ${database.programId}'),
                  if (database.grup != null) Text('Grup: ${database.grup}'),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const MainMenuScreen(),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
