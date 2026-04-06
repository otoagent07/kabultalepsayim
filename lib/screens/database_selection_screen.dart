import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/api_database.dart';
import '../models/api_company.dart';
import '../providers/selected_database_provider.dart';
import 'main_menu_screen.dart';

class DatabaseSelectionScreen extends StatefulWidget {
  final List<ApiDatabase> databases;
  final ApiCompany company;

  const DatabaseSelectionScreen({
    super.key,
    required this.databases,
    required this.company,
  });

  @override
  State<DatabaseSelectionScreen> createState() =>
      _DatabaseSelectionScreenState();
}

class _DatabaseSelectionScreenState extends State<DatabaseSelectionScreen> {
  static const List<Color> _accentColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
  ];

  void _onSelectDatabase(ApiDatabase database) {
    Provider.of<SelectedDatabaseProvider>(
      context,
      listen: false,
    ).setSelectedDatabase(database, widget.company);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MainMenuScreen(),
      ),
    );
  }

  Widget _buildDatabaseCard(
    BuildContext context,
    ApiDatabase database,
    Color color,
  ) {
    final t = Theme.of(context);
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: () => _onSelectDatabase(database),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  database.ad,
                  style: t.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${database.id}',
                  style: t.textTheme.bodyMedium,
                ),
                Text(
                  'Kod: ${database.kod}',
                  style: t.textTheme.bodyMedium,
                ),
                Text(
                  'Program ID: ${database.programId}',
                  style: t.textTheme.bodyMedium,
                ),
                if (database.grup != null)
                  Text(
                    'Grup: ${database.grup}',
                    style: t.textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontSizeFactor: 2.0),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(size: 48),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
            title: Text('Veritabanı Seçiniz'),
            centerTitle: true,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(32.0),
            itemCount: widget.databases.length,
            itemBuilder: (context, index) {
              final database = widget.databases[index];
              final color = _accentColors[index % _accentColors.length];
              return _buildDatabaseCard(context, database, color);
            },
          ),
        ),
      ),
    );
  }
}
