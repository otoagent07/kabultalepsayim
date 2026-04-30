import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/selected_database_provider.dart';
import 'barcode_inventory_selection_screen.dart';
import 'amber_request_selection_screen.dart';
import 'mal_kabul_selection_screen.dart';
import 'barkod_tanimla_screen.dart';
import '../widgets/alice_inspector_button.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontSizeFactor: 2.0),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(size: 48),
        child: Builder(
          builder: (themedContext) {
            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  iconSize: 28,
                  onPressed: () => Navigator.of(themedContext).pop(),
                ),
                title: Text('Ana Menü'),
                actions: [
                  const AliceInspectorButton(),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, child) {
                      return IconButton(
                        icon: Icon(
                          themeProvider.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                        iconSize: 28,
                        onPressed: () => themeProvider.toggleTheme(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    iconSize: 28,
                    onPressed: () {
                      Provider.of<SelectedDatabaseProvider>(
                        themedContext,
                        listen: false,
                      ).clearSelection();
                      Navigator.of(themedContext).pushReplacementNamed('/login');
                    },
                  ),
                ],
              ),
              body: SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Consumer<SelectedDatabaseProvider>(
                          builder: (context, databaseProvider, child) {
                            if (databaseProvider.selectedDatabase == null ||
                                databaseProvider.selectedCompany == null) {
                              return const SizedBox.shrink();
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              elevation: 2,
                              child: Container(
                                padding: const EdgeInsets.all(24.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(themedContext)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      Theme.of(themedContext)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      databaseProvider
                                          .selectedCompany!
                                          .fldSirketAdi,
                                      style: Theme.of(themedContext)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: (Theme.of(themedContext)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.fontSize ??
                                                    16) *
                                                0.5,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      databaseProvider.selectedDatabase!.ad,
                                      style: Theme.of(themedContext)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              themedContext,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: (Theme.of(themedContext)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.fontSize ??
                                                    12) *
                                                0.5,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 112),
                          child: _buildMenuButton(
                            themedContext,
                            'Mal Kabul',
                            Icons.inbox,
                            Colors.blue,
                            () {
                              Navigator.of(themedContext).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MalKabulSelectionScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 112),
                          child: _buildMenuButton(
                            themedContext,
                            'Amber Talep',
                            Icons.request_quote,
                            Colors.orange,
                            () {
                              Navigator.of(themedContext).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AmberRequestSelectionScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 112),
                          child: _buildMenuButton(
                            themedContext,
                            'Barkodlu Sayım',
                            Icons.qr_code_scanner,
                            Colors.green,
                            () {
                              Navigator.of(themedContext).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BarcodeInventorySelectionScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 5),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 112),
                          child: _buildMenuButton(
                            themedContext,
                            'Barkod Tanımla',
                            Icons.qr_code,
                            Colors.purple,
                            () {
                              Navigator.of(themedContext).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const BarkodTanimlaScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
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
              horizontal: 8.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
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
