import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../models/department_response.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'mal_kabul_screen.dart';
import '../widgets/alice_inspector_button.dart';

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
  bool _isCheckingOrders = false;
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
      final response = await ApiService.getDepartments(_token!, _dbId!);

      final login = ApiService.cachedLoginResponse;
      if (login != null) {
        _efaturaDbIdByName
          ..clear()
          ..addAll({
            for (final db in login.databases)
              if (db.programId == 3 && (db.databaseName ?? '').isNotEmpty)
                db.databaseName!: db.id,
          });
      }

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
                        'Kod: ${department.kod}   Şube: ${department.sube}\nefutadb_id: ${efaturaId ?? 'id yok'}',
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
    if (girisTip == 'Mal Kabul Giriş') {
      _goMalKabulGiris();
      return;
    }
    final dept = _selectedDepartment!;
    final efaturaDbId = (dept.eFatDb == null || dept.eFatDb!.isEmpty)
        ? null
        : _efaturaDbIdByName[dept.eFatDb!];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MalKabulScreen(
          selectedDate: _selectedDate,
          girisTip: girisTip,
          selectedDepartment: dept,
          efaturaDbId: efaturaDbId,
          efatSirketId: dept.eFatSirketId,
        ),
      ),
    );
  }

  Future<void> _goMalKabulGiris() async {
    final dept = _selectedDepartment!;
    final token = _token;
    final dbId = _dbId;
    if (token == null || dbId == null) return;

    setState(() => _isCheckingOrders = true);
    try {
      final tarih = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final all = await ApiService.getStokHareketByDate(
        token: token,
        dbId: dbId,
        tarih: tarih,
        sirket: dept.sube,
      );
      final orders = all.where((o) {
        final raw = o['Siparisno'];
        final v = raw is int ? raw : int.tryParse('$raw');
        return v != null && v != 0;
      }).toList();

      if (!mounted) return;

      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seçilen tarih ve şube için sipariş bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final efaturaDbId = (dept.eFatDb == null || dept.eFatDb!.isEmpty)
          ? null
          : _efaturaDbIdByName[dept.eFatDb!];

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => MalKabulScreen(
            selectedDate: _selectedDate,
            girisTip: 'Mal Kabul Giriş',
            selectedDepartment: dept,
            efaturaDbId: efaturaDbId,
            efatSirketId: dept.eFatSirketId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sipariş sorgusu başarısız: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingOrders = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd.MM.yyyy').format(_selectedDate);
    final deptEfaturaId = (_selectedDepartment == null ||
        _selectedDepartment!.eFatDb == null ||
        _selectedDepartment!.eFatDb!.isEmpty)
      ? 'id yok'
      : (_efaturaDbIdByName[_selectedDepartment!.eFatDb!] ?? 'id yok')
        .toString();
    final deptText = _selectedDepartment == null
        ? 'Seçiniz'
      : _selectedDepartment!.ad.trim();
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
        actions: const [AliceInspectorButton()],
      ),
      body: (_isLoading || _isCheckingOrders)
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
                          _entryButtonWithValue(
                            text: 'Tarih Seçin',
                            value: dateText,
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                            onPressed: _selectDate,
                          ),
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
                          const SizedBox(height: 6),
                          _entryButton(
                            text: 'Sipariş No ile Giriş',
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
                          _entryButton(
                            text: 'Mal Kabul Giriş',
                            icon: Icons.inventory_2_outlined,
                            color: Colors.indigo,
                            onPressed: () => _go('Mal Kabul Giriş'),
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

