import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/department.dart';
import '../models/department_response.dart';
import '../models/login_response.dart';
import '../models/sube.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/date_selection_tile.dart';
import '../widgets/department_selection_tile.dart';
import '../widgets/selection_tile.dart';
import 'amber_request_screen.dart';
import '../widgets/alice_inspector_button.dart';

/// Amber talep öncesi tarih, departman, alan/servis ve şube seçimi.
class AmberRequestSelectionScreen extends StatefulWidget {
  const AmberRequestSelectionScreen({super.key});

  @override
  State<AmberRequestSelectionScreen> createState() =>
      _AmberRequestSelectionScreenState();
}

class _AmberRequestSelectionScreenState
    extends State<AmberRequestSelectionScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment;
  Department? _selectedAlanServis;
  Sube? _selectedSube;

  List<Department> _departments = [];
  List<Department> _alanServisList = [];
  List<Sube> _subeler = [];
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum veya veritabanı bilgisi bulunamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadDepartments(), _loadSubeler()]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDepartments() async {
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
          _departments = response.value
              .where((d) => d.anadepo == true)
              .toList();
          _alanServisList = response.value
              .where((d) => d.anadepo == false)
              .toList();

          if (_selectedDepartment == null && _departments.isNotEmpty) {
            _selectedDepartment = _departments.first;
          }
          if (_selectedAlanServis == null && _alanServisList.isNotEmpty) {
            _selectedAlanServis = _alanServisList.first;
          }
        });
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

  Future<void> _loadSubeler() async {
    try {
      final response = await ApiService.getSubeler(
        _token!,
        _dbId!,
        'Sube',
        false,
      );

      if (response.isSucceded) {
        setState(() {
          _subeler = response.value;
          if (_selectedSube == null && _subeler.isNotEmpty) {
            _selectedSube = _subeler.first;
          }
        });
      }
    } catch (e) {
      log('Şube yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şube yükleme hatası: $e'),
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
                  minimumDate: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    1,
                  ),
                  maximumDate: DateTime(DateTime.now().year + 1, 12, 31),
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
                        backgroundColor: isSelected
                            ? Colors.blue
                            : Colors.grey[300],
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

  void _selectAlanServis() {
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
              'Alan/Servis Seçiniz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _alanServisList.length,
                itemBuilder: (context, index) {
                  final alanServis = _alanServisList[index];
                  final isSelected = _selectedAlanServis?.id == alanServis.id;
                  final efaturaId = (alanServis.eFatDb == null ||
                          alanServis.eFatDb!.isEmpty)
                      ? null
                      : _efaturaDbIdByName[alanServis.eFatDb!];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.green[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.green
                            : Colors.grey[300],
                        child: Text(
                          alanServis.kod,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        alanServis.ad,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Kod: ${alanServis.kod}   Şube: ${alanServis.sube}\nefutadb_id: ${efaturaId ?? 'id yok'}',
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedAlanServis = alanServis;
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

  void _selectSube() {
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
              'Şube Seçiniz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _subeler.length,
                itemBuilder: (context, index) {
                  final sube = _subeler[index];
                  final isSelected = _selectedSube?.id == sube.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isSelected ? Colors.orange[100] : null,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Colors.orange
                            : Colors.grey[300],
                        child: Text(
                          sube.kod,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        sube.ad,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('Kod: ${sube.kod}'),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.orange)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedSube = sube;
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

  void _continueToRequest() {
    if (_selectedDepartment == null ||
        _selectedAlanServis == null ||
        _selectedSube == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm seçimleri yapınız'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AmberRequestScreen(
          selectedDate: _selectedDate,
          selectedDepartment: _selectedDepartment!,
          selectedAlanServis: _selectedAlanServis!,
          selectedSube: _selectedSube!,
        ),
      ),
    );
  }

  static const double _kLabelFs = 24;
  static const double _kValueFs = 20;
  static const double _kKodFs = 16;
  static const double _kIconSize = 40;

  String _efaturaIdTextFor(Department? dept) {
    if (dept == null || dept.eFatDb == null || dept.eFatDb!.isEmpty) {
      return 'efutadb_id: id yok';
    }
    final id = _efaturaDbIdByName[dept.eFatDb!];
    return 'efutadb_id: ${id ?? 'id yok'}';
  }

  Widget _buildSelectionCards() {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateSelectionTile(
            onTap: _selectDate,
            selectedDate: _selectedDate,
            label: 'Tarih',
            labelFontSize: _kLabelFs,
            valueFontSize: _kValueFs,
            iconSize: _kIconSize,
          ),
          const SizedBox(height: 3),
          DepartmentSelectionTile(
            onTap: _selectDepartment,
            departmentName: _selectedDepartment?.ad,
            departmentKod: _selectedDepartment?.kod,
            subeText: _selectedDepartment?.sube,
            efutadbIdText: _selectedDepartment == null
                ? null
                : _efaturaIdTextFor(_selectedDepartment),
            label: 'Departman',
            selectedColor: Colors.blue,
            labelFontSize: _kLabelFs,
            valueFontSize: _kValueFs,
            kodFontSize: _kKodFs,
            iconSize: _kIconSize,
          ),
          const SizedBox(height: 3),
          SelectionTile(
            onTap: _selectAlanServis,
            icon: Icons.room_service,
            iconColor: _selectedAlanServis != null ? Colors.green : Colors.grey,
            cardTint: _selectedAlanServis != null ? Colors.green[50] : null,
            label: 'Alan/Servis',
            value: _selectedAlanServis?.ad ?? 'Seçiniz',
            kodLine: _selectedAlanServis != null
                ? 'Kod: ${_selectedAlanServis!.kod}'
                : null,
            valueColor: _selectedAlanServis != null
                ? Colors.green[800]
                : Colors.grey[600],
            valueWeight: _selectedAlanServis != null
                ? FontWeight.bold
                : FontWeight.normal,
            kodColor: Colors.green[600],
            labelFontSize: _kLabelFs,
            valueFontSize: _kValueFs,
            kodFontSize: _kKodFs,
            iconSize: _kIconSize,
          ),
          const SizedBox(height: 3),
          SelectionTile(
            onTap: _selectSube,
            icon: Icons.location_city,
            iconColor: _selectedSube != null ? Colors.orange : Colors.grey,
            cardTint: _selectedSube != null ? Colors.orange[50] : null,
            label: 'Şube',
            value: _selectedSube?.ad ?? 'Seçiniz',
            kodLine: _selectedSube != null
                ? 'Kod: ${_selectedSube!.kod}'
                : null,
            valueColor: _selectedSube != null
                ? Colors.orange[800]
                : Colors.grey[600],
            valueWeight: _selectedSube != null
                ? FontWeight.bold
                : FontWeight.normal,
            kodColor: Colors.orange[600],
            labelFontSize: _kLabelFs,
            valueFontSize: _kValueFs,
            kodFontSize: _kKodFs,
            iconSize: _kIconSize,
          ),
        ],
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
          'Amber Talep — Seçim',
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
                      onPressed: _continueToRequest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        backgroundColor: Colors.orange[700],
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
