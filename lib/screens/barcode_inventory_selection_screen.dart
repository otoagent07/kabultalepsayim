import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../models/department_response.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/date_selection_tile.dart';
import 'barcode_inventory_screen.dart';
import '../widgets/alice_inspector_button.dart';

class BarcodeInventorySelectionScreen extends StatefulWidget {
  const BarcodeInventorySelectionScreen({super.key});

  @override
  State<BarcodeInventorySelectionScreen> createState() =>
      _BarcodeInventorySelectionScreenState();
}

class _BarcodeInventorySelectionScreenState
    extends State<BarcodeInventorySelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment;

  List<Department> _departments = [];
  final Map<String, int> _efaturaDbIdByName = {};
  bool _isLoading = true;

  String? _token;
  int? _dbId;

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
      await _loadDepartments();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final response = await ApiService.getDepartments(_token!, _dbId!);

      final login = ApiService.cachedLoginResponse;
      if (login != null) {
        _efaturaDbIdByName
          ..clear()
          ..addAll({
            for (final db in login.databases)
              if (db.programId == 3 && (db.databaseName ?? '').trim().isNotEmpty)
                db.databaseName!.trim().toLowerCase(): db.id,
          });
      }

      if (response.isSucceded) {
        setState(() {
          _departments = response.value;
          if (_selectedDepartment == null && _departments.isNotEmpty) {
            _selectedDepartment = _departments.first;
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Departman listesi alınamadı: ${response.message ?? 'Bilinmeyen hata'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      log('Departman yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Departman yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Widget _entryButtonWithValue({
    required String text,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    List<String>? detailLines,
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
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (detailLines != null && detailLines.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      for (final line in detailLines)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                    ],
                  ],
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

  void _selectDepartment() {
    if (_departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departman listesi yükleniyor...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                  final dept = _departments[index];
                  final isSelected = _selectedDepartment?.id == dept.id;
                  final efaturaId =
                      (dept.eFatDb == null || dept.eFatDb!.trim().isEmpty)
                          ? null
                          : _efaturaDbIdByName[dept.eFatDb!.trim().toLowerCase()];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.blue[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.blue
                            : Colors.grey[300],
                        child: Text(
                          dept.kod,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        dept.ad,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Kod: ${dept.kod}   Şube: ${dept.sube}\nefutadb_id: ${efaturaId ?? 'id yok'}',
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDepartment = dept;
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

  Widget _buildSelectionCards() {
    final deptEfaturaId = (_selectedDepartment == null ||
            _selectedDepartment!.eFatDb == null ||
            _selectedDepartment!.eFatDb!.trim().isEmpty)
        ? 'id yok'
        : (_efaturaDbIdByName[
                    _selectedDepartment!.eFatDb!.trim().toLowerCase()] ??
                'id yok')
            .toString();
    final deptText = _selectedDepartment == null
        ? 'Seçiniz'
        : _selectedDepartment!.ad.trim();

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateSelectionTile(
            onTap: _selectDate,
            selectedDate: _selectedDate,
            label: 'Tarih Seçin',
          ),
          const SizedBox(height: 3),
          _entryButtonWithValue(
            text: 'Departman Seçin',
            value: deptText,
            icon: Icons.business,
            color: Colors.blue,
            onPressed: _selectDepartment,
            detailLines: _selectedDepartment == null
                ? null
                : [
                    'Kod: ${_selectedDepartment!.kod}',
                    'Şube: ${_selectedDepartment!.sube}',
                    'efutadb_id: $deptEfaturaId',
                  ],
          ),
        ],
      ),
    );
  }

  void _continue() {
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
        builder: (context) => BarcodeInventoryScreen(
          selectedDate: _selectedDate,
          selectedDepartment: _selectedDepartment!,
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
          'Barkodlu Sayım — Seçim',
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
        ),
        actions: const [AliceInspectorButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(child: _buildSelectionCards()),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: ElevatedButton(
                      onPressed: _continue,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                'Devam',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 28),
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
