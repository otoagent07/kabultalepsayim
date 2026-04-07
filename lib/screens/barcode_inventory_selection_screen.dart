import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'barcode_inventory_screen.dart';

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
  bool _isLoading = true;

  String? _token;
  int? _dbId;

  static const double _kLabelFs = 24;
  static const double _kValueFs = 20;
  static const double _kKodFs = 16;
  static const double _kIconSize = 40;

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
      _dbId = selectedDb.id;
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

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.green[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.green
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
                      subtitle: Text('Kod: ${dept.kod}'),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
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

  Widget _fullWidthSelectionTile({
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    Color? cardTint,
    required String label,
    required String value,
    String? kodLine,
    Color? valueColor,
    FontWeight? valueWeight,
    Color? kodColor,
  }) {
    return Card(
      color: cardTint,
      margin: const EdgeInsets.all(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: _kIconSize),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: _kLabelFs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: _kValueFs,
                        color: valueColor ?? Colors.grey[700],
                        fontWeight: valueWeight ?? FontWeight.normal,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (kodLine != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        kodLine,
                        style: TextStyle(
                          fontSize: _kKodFs,
                          color: kodColor ?? Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCards() {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fullWidthSelectionTile(
            onTap: _selectDate,
            icon: Icons.calendar_today,
            iconColor: Colors.blue,
            label: 'Tarih',
            value: DateFormat('dd.MM.yyyy').format(_selectedDate),
            valueColor: Colors.grey[700],
          ),
          const SizedBox(height: 3),
          _fullWidthSelectionTile(
            onTap: _selectDepartment,
            icon: Icons.business,
            iconColor: _selectedDepartment != null ? Colors.green : Colors.grey,
            cardTint: _selectedDepartment != null ? Colors.green[50] : null,
            label: 'Departman',
            value: _selectedDepartment?.ad ?? 'Seçiniz',
            kodLine: _selectedDepartment != null
                ? 'Kod: ${_selectedDepartment!.kod}'
                : null,
            valueColor: _selectedDepartment != null
                ? Colors.green[800]
                : Colors.grey[600],
            valueWeight: _selectedDepartment != null
                ? FontWeight.bold
                : FontWeight.normal,
            kodColor: Colors.green[600],
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
