import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../models/department_response.dart';
import '../models/login_response.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/date_selection_tile.dart';
import '../widgets/department_selection_tile.dart';
import 'mal_kabul_screen.dart';

class MalKabulSelectionScreen extends StatefulWidget {
  const MalKabulSelectionScreen({super.key});

  @override
  State<MalKabulSelectionScreen> createState() => _MalKabulSelectionScreenState();
}

class _MalKabulSelectionScreenState extends State<MalKabulSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment;
  List<Department> _departments = [];
  final Map<String, int> _efaturaDbIdByName = {};
  bool _isLoading = true;
  String? _token;
  int? _dbId;

  static const double _kLabelFs = 24;
  static const double _kValueFs = 20;
  static const double _kIconSize = 40;

  String _efaturaIdTextForSelected() {
    final dept = _selectedDepartment;
    if (dept == null || dept.eFatDb == null || dept.eFatDb!.isEmpty) {
      return 'efutadb_id: id yok';
    }
    final id = _efaturaDbIdByName[dept.eFatDb!];
    return 'efutadb_id: ${id ?? 'id yok'}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final selectedDb = Provider.of<SelectedDatabaseProvider>(
      context,
      listen: false,
    ).selectedDatabase;
    if (selectedDb != null) {
      _dbId = selectedDb.dbBackOfficeId ?? selectedDb.id;
    }

    _token = await StorageService.getToken();

    if (!mounted) return;

    if (_token == null || _dbId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum veya veritabanı bilgisi bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getDepartments(_token!, _dbId!),
        ApiService.loginByToken(_token!),
      ]);

      final response = results[0] as DepartmentResponse;
      final login = results[1] as LoginResponse;

      _efaturaDbIdByName
        ..clear()
        ..addAll({
          for (final db in login.databases)
            if (db.programId == 3 && (db.databaseName ?? '').isNotEmpty)
              db.databaseName!: db.id,
        });

      if (response.isSucceded) {
        setState(() {
          _departments = response.value;
          if (_selectedDepartment == null && _departments.isNotEmpty) {
            _selectedDepartment = _departments.first;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Departman listesi alınamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectDate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (BuildContext context) => Container(
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tarih Seçin',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 36),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Tamam',
                    style: TextStyle(fontSize: 28),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  textTheme: const CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(fontSize: 32),
                  ),
                ),
                child: CupertinoDatePicker(
                  initialDateTime: _selectedDate,
                  mode: CupertinoDatePickerMode.date,
                  use24hFormat: true,
                  showDayOfWeek: true,
                  itemExtent: 64,
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDepartment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Departman Seçiniz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _departments.length,
                itemBuilder: (context, index) {
                  final department = _departments[index];
                  final isSelected = _selectedDepartment?.id == department.id;
                  final efaturaId = (department.eFatDb == null ||
                          department.eFatDb!.isEmpty)
                      ? null
                      : _efaturaDbIdByName[department.eFatDb!];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.blue[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isSelected ? Colors.blue : Colors.grey[300],
                        child: Text(
                          department.kod,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        department.ad,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Kod: ${department.kod}\nefutadb_id: ${efaturaId ?? 'id yok'}',
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDepartment = department;
                        });
                        Navigator.pop(context);
                      },
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

  void _go(String girisTip) {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen departman seçiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MalKabulScreen(
          selectedDate: _selectedDate,
          girisTip: girisTip,
          selectedDepartment: _selectedDepartment!,
        ),
      ),
    );
  }

  Widget _entryButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.all(3),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Geri',
        ),
        title: const Text(
          'Mal Kabul — Seçim',
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DateSelectionTile(
                            onTap: _selectDate,
                            selectedDate: _selectedDate,
                            label: 'Tarih Seçin',
                            labelFontSize: _kLabelFs,
                            valueFontSize: _kValueFs,
                            iconSize: _kIconSize,
                          ),
                          DepartmentSelectionTile(
                            onTap: _selectDepartment,
                            departmentName: _selectedDepartment?.ad,
                            departmentKod: _selectedDepartment?.kod,
                            efutadbIdText: _selectedDepartment == null
                                ? null
                                : _efaturaIdTextForSelected(),
                            label: 'Departman Seçin',
                            selectedColor: Colors.blue,
                            labelFontSize: _kLabelFs,
                            valueFontSize: _kValueFs,
                            kodFontSize: 16,
                            iconSize: _kIconSize,
                          ),
                          const SizedBox(height: 6),
                          _entryButton(
                            text: 'Sipariş No İle Giriş',
                            icon: Icons.receipt_long,
                            color: Colors.blue,
                            onPressed: () => _go('Sipariş No'),
                          ),
                          _entryButton(
                            text: 'İrsaliye ile Giriş',
                            icon: Icons.local_shipping,
                            color: Colors.green,
                            onPressed: () => _go('İrsaliye'),
                          ),
                          _entryButton(
                            text: 'Fatura ile Giriş',
                            icon: Icons.description,
                            color: Colors.orange,
                            onPressed: () => _go('Fatura'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

