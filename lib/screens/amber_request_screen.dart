import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:provider/provider.dart';
import '../models/department.dart';
import '../models/sube.dart';
import '../models/stok_master.dart';
import '../models/amber_talep_item.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../providers/selected_database_provider.dart';

class AmberRequestScreen extends StatefulWidget {
  const AmberRequestScreen({super.key});

  @override
  State<AmberRequestScreen> createState() => _AmberRequestScreenState();
}

class _AmberRequestScreenState extends State<AmberRequestScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment; // Departman
  Department? _selectedAlanServis; // Alan/Servis
  Sube? _selectedSube; // Şube

  List<StokMaster> _allStoklar = []; // Tüm stoklar (ilk açılışta yüklenir)
  final List<AmberTalepItem> _talepItems = []; // Talep edilen ürünler

  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(
    debugLabel: 'BarcodeInput',
    skipTraversal: true,
  );

  List<Department> _departments = []; // Anadepo = true olanlar
  List<Department> _alanServisList = []; // Anadepo = false olanlar
  List<Sube> _subeler = []; // Şubeler

  bool _isLoadingDepartments = false;
  bool _isLoadingSubeler = false;
  bool _isLoadingStoklar = false;
  bool _isSaving = false;

  String? _token;
  int? _dbId;

  @override
  void initState() {
    super.initState();

    // Klavye açılmasını engelle
    _barcodeFocusNode.addListener(() {
      if (_barcodeFocusNode.hasFocus) {
        // Klavye açılmaya çalışırsa kapat
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });

    // Lazer okuyucu için odaklanma
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    // Token ve database ID'yi al
    _token = await StorageService.getToken();

    if (!mounted) return;

    final selectedDb = Provider.of<SelectedDatabaseProvider>(
      context,
      listen: false,
    ).selectedDatabase;

    if (selectedDb != null) {
      _dbId = selectedDb.id;
    }

    // Departmanları, şubeleri ve stokları yükle
    if (_token != null && _dbId != null) {
      await Future.wait([_loadDepartments(), _loadSubeler(), _loadStoklar()]);
    }
  }

  Future<void> _loadStoklar() async {
    // Eğer zaten yüklenmişse tekrar yükleme
    if (_allStoklar.isNotEmpty) {
      log('Stoklar zaten yüklü, yeniden yükleme yapılmıyor');
      return;
    }

    if (_token == null || _dbId == null) return;

    setState(() {
      _isLoadingStoklar = true;
    });

    try {
      log('Stoklar API\'den yükleniyor...');
      final response = await ApiService.getStokMaster(_token!, _dbId!, false);

      if (response.isSucceded) {
        setState(() {
          _allStoklar = response.value;
        });
        log('${_allStoklar.length} adet stok yüklendi');
      }
    } catch (e) {
      log('Stok yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok listesi yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingStoklar = false;
      });
    }
  }

  Future<void> _loadDepartments() async {
    if (_token == null || _dbId == null) return;

    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      final response = await ApiService.getAmberDepartments(
        _token!,
        _dbId!,
        'Departman',
        false,
      );

      if (response.isSucceded) {
        setState(() {
          // Anadepo = true olanları departman listesine ekle
          _departments = response.value.where((dept) => dept.anadepo).toList();
          // Anadepo = false olanları alan/servis listesine ekle
          _alanServisList = response.value
              .where((dept) => !dept.anadepo)
              .toList();

          // İlk departmanı otomatik seç
          if (_departments.isNotEmpty && _selectedDepartment == null) {
            _selectedDepartment = _departments.first;
          }

          // İlk alan/servisi otomatik seç
          if (_alanServisList.isNotEmpty && _selectedAlanServis == null) {
            _selectedAlanServis = _alanServisList.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Departman listesi yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }

  Future<void> _loadSubeler() async {
    if (_token == null || _dbId == null) return;

    setState(() {
      _isLoadingSubeler = true;
    });

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

          // İlk şubeyi otomatik seç
          if (_subeler.isNotEmpty && _selectedSube == null) {
            _selectedSube = _subeler.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Şube listesi yüklenemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingSubeler = false;
      });
    }
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _selectDate() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header with title and done button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tarih Seçin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam'),
                ),
              ],
            ),
            const Divider(),
            // Date picker
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _selectedDate,
                mode: CupertinoDatePickerMode.date,
                use24hFormat: true,
                showDayOfWeek: true,
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDepartment() {
    if (_isLoadingDepartments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departmanlar yükleniyor, lütfen bekleyin...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departman bulunamadı'),
          backgroundColor: Colors.red,
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
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Departman Seçiniz',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _departments.length,
                itemBuilder: (context, index) {
                  final dept = _departments[index];
                  final isSelected = _selectedDepartment?.id == dept.id;

                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDepartment = dept;
                          // Departman değiştiğinde alan/servis seçimini sıfırla
                          _selectedAlanServis = null;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: dept.id,
                              groupValue: _selectedDepartment?.id,
                              onChanged: (value) {
                                setState(() {
                                  _selectedDepartment = dept;
                                  _selectedAlanServis = null;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dept.ad,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                  ),
                                  Text(
                                    'Kod: ${dept.kod}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
    if (_isLoadingDepartments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alan/Servis listesi yükleniyor, lütfen bekleyin...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_alanServisList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alan/Servis bulunamadı'),
          backgroundColor: Colors.red,
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
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alan/Servis Seçiniz',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _alanServisList.length,
                itemBuilder: (context, index) {
                  final alanServis = _alanServisList[index];
                  final isSelected = _selectedAlanServis?.id == alanServis.id;

                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? Colors.green.shade50 : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAlanServis = alanServis;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: alanServis.id,
                              groupValue: _selectedAlanServis?.id,
                              onChanged: (value) {
                                setState(() {
                                  _selectedAlanServis = alanServis;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alanServis.ad,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                  ),
                                  Text(
                                    'Kod: ${alanServis.kod}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
    if (_isLoadingSubeler) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şubeler yükleniyor, lütfen bekleyin...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_subeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şube bulunamadı'),
          backgroundColor: Colors.red,
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
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Şube Seçiniz',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _subeler.length,
                itemBuilder: (context, index) {
                  final sube = _subeler[index];
                  final isSelected = _selectedSube?.id == sube.id;

                  return Card(
                    elevation: isSelected ? 4 : 1,
                    color: isSelected ? Colors.orange.shade50 : null,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedSube = sube;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: sube.id,
                              groupValue: _selectedSube?.id,
                              onChanged: (value) {
                                setState(() {
                                  _selectedSube = sube;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sube.ad,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : null,
                                        ),
                                  ),
                                  Text(
                                    'Kod: ${sube.kod}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _showProductSelectionDialog() {
    // Stoklar yükleniyorsa bekle
    if (_isLoadingStoklar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürünler yükleniyor, lütfen bekleyin...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Stoklar boşsa uyar
    if (_allStoklar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtreleme - her arama değiştiğinde hesaplanacak
          final filteredStoklar = searchController.text.isEmpty
              ? _allStoklar
              : _allStoklar.where((stok) {
                  final searchText = searchController.text.toLowerCase();
                  return stok.ad.toLowerCase().contains(searchText) ||
                      stok.genelKod.toLowerCase().contains(searchText) ||
                      stok.barkod1.toLowerCase().contains(searchText);
                }).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Text('Ürün Seçiniz'),
                const Spacer(),
                Text(
                  '${filteredStoklar.length} ürün',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ürün adı, stok kodu veya barkod ara...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {}); // Sadece UI'ı yenile
                    },
                  ),
                  const SizedBox(height: 16),
                  // Products List - ListView.builder ile performanslı
                  Expanded(
                    child: filteredStoklar.isEmpty
                        ? const Center(
                            child: Text(
                              'Arama kriterlerine uygun ürün bulunamadı',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredStoklar.length,
                            itemBuilder: (context, index) {
                              final stok = filteredStoklar[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.inventory,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    stok.ad,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Kod: ${stok.genelKod}'),
                                      Text('Barkod: ${stok.barkod1}'),
                                      Text('Birim: ${stok.anabirim}'),
                                    ],
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _processStokSelection(stok);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Seç'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _processBarcode(String barcode) {
    // Barkod ile stok ara
    final stok = _allStoklar.firstWhere(
      (s) => s.barkod1 == barcode,
      orElse: () => StokMaster(
        id: 0,
        anagrup: '',
        aragrup: '',
        altgrup: '',
        kod: '',
        genelKod: '',
        ad: '',
        anabirim: '',
        altbirim: '',
        barkod1: '',
      ),
    );

    if (stok.genelKod.isNotEmpty) {
      // Barkod bulundu, stok bilgilerini çek
      _processStokSelection(stok);
    } else {
      // Ürün bulunamadı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ürün bulunamadı: $barcode'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // Odaklanmayı koru
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _processStokSelection(StokMaster stok) async {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce departman seçiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Loading göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Stok birim fiyat bilgisini çek
      final response = await ApiService.getStokBirimFiyat(
        _token!,
        _dbId!,
        stok.genelKod,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        _selectedDepartment!.kod,
      );

      if (mounted) {
        Navigator.pop(context); // Loading'i kapat
      }

      if (response.isSucceded && response.value.isNotEmpty) {
        final fiyatBilgisi = response.value.first;

        // Miktar girme dialogunu aç
        if (mounted) {
          _showQuantityDialog(
            stok,
            fiyatBilgisi.kalanMiktar,
            fiyatBilgisi.birimFiyat,
            fiyatBilgisi.birim,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stok bilgisi alınamadı'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Loading'i kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final String? result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerPage()),
      );

      if (result != null && result.isNotEmpty) {
        _processBarcode(result);
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      log('Kamera okuma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kamera hatası: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showQuantityDialog(
    StokMaster stok,
    double kalanMiktar,
    double birimFiyat,
    String birim,
  ) {
    final TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Miktar Gir - ${stok.ad}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stok Kodu: ${stok.genelKod}'),
            Text('Kalan Miktar: $kalanMiktar $birim'),
            Text('Birim Fiyat: ${birimFiyat.toStringAsFixed(2)} ₺'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Miktar',
                hintText: 'Miktar giriniz',
                suffix: Text(birim),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final miktar = int.tryParse(quantityController.text) ?? 0;
              if (miktar > 0) {
                _addTalepItem(stok, miktar, birimFiyat, birim);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Geçerli bir miktar giriniz'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _addTalepItem(
    StokMaster stok,
    int miktar,
    double birimFiyat,
    String birim,
  ) {
    final tutar = miktar * birimFiyat;

    // Aynı üründen var mı kontrol et
    final existingIndex = _talepItems.indexWhere(
      (item) => item.stokkod == stok.genelKod,
    );

    if (existingIndex != -1) {
      // Var olan ürünü güncelle
      setState(() {
        _talepItems[existingIndex] = AmberTalepItem(
          stokkod: stok.genelKod,
          stokAd: stok.ad,
          birim: birim,
          barkod: stok.barkod1,
          miktar: miktar,
          birimFiyat: birimFiyat,
          tutar: tutar,
          kalanMiktar: miktar.toDouble(),
        );
        // Üste taşı
        final item = _talepItems.removeAt(existingIndex);
        _talepItems.insert(0, item);
      });
    } else {
      // Yeni ürün ekle
      setState(() {
        _talepItems.insert(
          0,
          AmberTalepItem(
            stokkod: stok.genelKod,
            stokAd: stok.ad,
            birim: birim,
            barkod: stok.barkod1,
            miktar: miktar,
            birimFiyat: birimFiyat,
            tutar: tutar,
            kalanMiktar: miktar.toDouble(),
          ),
        );
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${stok.ad} eklendi'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );

    // Odaklanmayı koru
    _barcodeFocusNode.requestFocus();
  }

  void _showProductQuantityDialog(Product product) {
    final currentQuantity = _requestedItems[product.stokkod] ?? 0;
    final TextEditingController addQuantityController = TextEditingController();
    final TextEditingController totalQuantityController =
        TextEditingController();
    final FocusNode addQuantityFocusNode = FocusNode();
    final FocusNode totalQuantityFocusNode = FocusNode();
    bool isAddQuantityFocused = true;
    bool isCurrentRequestExpanded = false;

    // Focus listener'ları ekle
    addQuantityFocusNode.addListener(() {
      if (addQuantityFocusNode.hasFocus) {
        isAddQuantityFocused = true;
      }
    });

    totalQuantityFocusNode.addListener(() {
      if (totalQuantityFocusNode.hasFocus) {
        isAddQuantityFocused = false;
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final addQuantity = int.tryParse(addQuantityController.text) ?? 0;
          final totalQuantity = int.tryParse(totalQuantityController.text) ?? 0;

          // Hesaplamalar
          final calculatedTotal = currentQuantity + addQuantity;
          final calculatedAdd = totalQuantity - currentQuantity;

          // Görüntülenecek değerler
          final displayTotal = isAddQuantityFocused
              ? calculatedTotal
              : (totalQuantity > 0 ? totalQuantity : currentQuantity);
          final displayAdd = isAddQuantityFocused ? addQuantity : calculatedAdd;

          // Sonuç miktarı (kaydetme için)
          final finalQuantity = isAddQuantityFocused
              ? calculatedTotal
              : (totalQuantity > 0 ? totalQuantity : currentQuantity);

          final isValidQuantity =
              finalQuantity > 0 && finalQuantity <= product.kalanmiktar;

          return AlertDialog(
            title: const Text('Miktar Gir'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mevcut talep accordion
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          // Accordion header
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                isCurrentRequestExpanded =
                                    !isCurrentRequestExpanded;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Mevcut Talep: $currentQuantity',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Toplam Miktar: ${product.kalanmiktar}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    isCurrentRequestExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Accordion content
                          if (isCurrentRequestExpanded) ...[
                            const Divider(height: 1, thickness: 1),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Stok Kodu:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            product.stokkod,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Mevcut Miktar:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            '${product.kalanmiktar} adet',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Fiyat:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          Text(
                                            NumberFormat.currency(
                                              locale: 'tr_TR',
                                              symbol: '₺',
                                            ).format(product.fiyat),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // İki miktar input alanı yan yana
                    Row(
                      children: [
                        // Eklenecek/Çıkarılacak miktar
                        Expanded(
                          child: TextField(
                            controller: addQuantityController,
                            focusNode: addQuantityFocusNode,
                            readOnly: true,
                            showCursor: true,
                            enableInteractiveSelection: true,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isAddQuantityFocused
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Eklenecek/Çıkarılacak',
                              hintText: 'Miktar girin',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: isAddQuantityFocused
                                      ? Colors.blue
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: () {
                              setDialogState(() {
                                isAddQuantityFocused = true;
                                addQuantityFocusNode.requestFocus();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Toplam miktar
                        Expanded(
                          child: TextField(
                            controller: totalQuantityController,
                            focusNode: totalQuantityFocusNode,
                            readOnly: true,
                            showCursor: true,
                            enableInteractiveSelection: true,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: !isAddQuantityFocused
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Toplam Miktar',
                              hintText: 'Toplam girin',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: !isAddQuantityFocused
                                      ? Colors.green
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: () {
                              setDialogState(() {
                                isAddQuantityFocused = false;
                                totalQuantityFocusNode.requestFocus();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Sonuç gösterimi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isValidQuantity
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isValidQuantity
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            'Sonuç: $displayTotal',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          if (displayAdd != 0 &&
                              (isAddQuantityFocused
                                  ? addQuantity > 0
                                  : totalQuantity > 0))
                            Text(
                              displayAdd > 0
                                  ? 'Eklenecek: +$displayAdd'
                                  : 'Çıkarılacak: $displayAdd',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: displayAdd > 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Özel sayısal klavye
                    _buildDualModeKeyboard(
                      addQuantityController,
                      totalQuantityController,
                      isAddQuantityFocused,
                      setDialogState,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    flex: 7,
                    child: ElevatedButton(
                      onPressed: isValidQuantity
                          ? () {
                              _addProductToRequest(product, finalQuantity);
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Kaydet'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDualModeKeyboard(
    TextEditingController addQuantityController,
    TextEditingController totalQuantityController,
    bool isAddQuantityFocused,
    StateSetter setDialogState,
  ) {
    return Container(
      width: 240,
      child: Column(
        children: [
          // İlk satır: 1, 2, 3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDualModeNumberButton(
                '1',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '2',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '3',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDualModeNumberButton(
                '4',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '5',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '6',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDualModeNumberButton(
                '7',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '8',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildDualModeNumberButton(
                '9',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dördüncü satır: Temizle, 0, Sil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('C', () {
                if (isAddQuantityFocused) {
                  addQuantityController.text = '';
                  addQuantityController.selection = TextSelection.fromPosition(
                    TextPosition(offset: addQuantityController.text.length),
                  );
                } else {
                  totalQuantityController.text = '';
                  totalQuantityController
                      .selection = TextSelection.fromPosition(
                    TextPosition(offset: totalQuantityController.text.length),
                  );
                }
                setDialogState(() {});
              }),
              _buildDualModeNumberButton(
                '0',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildActionButton('⌫', () {
                if (isAddQuantityFocused) {
                  if (addQuantityController.text.isNotEmpty) {
                    addQuantityController.text = addQuantityController.text
                        .substring(0, addQuantityController.text.length - 1);
                  }
                  addQuantityController.selection = TextSelection.fromPosition(
                    TextPosition(offset: addQuantityController.text.length),
                  );
                } else {
                  if (totalQuantityController.text.isNotEmpty) {
                    totalQuantityController.text = totalQuantityController.text
                        .substring(0, totalQuantityController.text.length - 1);
                  }
                  totalQuantityController
                      .selection = TextSelection.fromPosition(
                    TextPosition(offset: totalQuantityController.text.length),
                  );
                }
                setDialogState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDualModeNumberButton(
    String number,
    TextEditingController addQuantityController,
    TextEditingController totalQuantityController,
    bool isAddQuantityFocused,
    StateSetter setDialogState,
  ) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (isAddQuantityFocused) {
            // Eklenecek/çıkarılacak miktar girişi
            addQuantityController.text += number;
            addQuantityController.selection = TextSelection.fromPosition(
              TextPosition(offset: addQuantityController.text.length),
            );
          } else {
            // Toplam miktar girişi
            totalQuantityController.text += number;
            totalQuantityController.selection = TextSelection.fromPosition(
              TextPosition(offset: totalQuantityController.text.length),
            );
          }
          setDialogState(() {});
        },
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          number,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDuzeltButton(String stokkod, String stokad) {
    return SizedBox(
      width: 120,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: () {
          final product = _products.firstWhere(
            (p) => p.stokkod == stokkod,
            orElse: () =>
                Product(stokad: '', stokkod: '', kalanmiktar: 0, fiyat: 0),
          );
          if (product.stokkod.isNotEmpty) {
            _showProductQuantityDialog(product);
          }
        },
        icon: const Icon(Icons.edit, size: 20),
        label: const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: Text('Düzelt'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSilButton(String stokkod, String stokad, bool isRequested) {
    return SizedBox(
      width: 120,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: isRequested
            ? () => _showDeleteConfirmationDialog(stokkod, stokad)
            : null,
        icon: const Icon(Icons.delete, size: 20),
        label: const Text('Sil'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRequested
              ? Colors.red.shade700
              : Colors.grey.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(String stokkod, String stokad) {
    final currentQuantity = _requestedItems[stokkod] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stok Kodu: $stokkod',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (stokad.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ürün: $stokad'),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Talep Edilen Miktar: $currentQuantity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu ürünü listeden silmek istediğinize emin misiniz?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: 7,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _requestedItems.remove(stokkod);
                      _requestItems.removeWhere(
                        (item) => item.stokkod == stokkod,
                      );
                    });
                    Navigator.pop(context);
                    // Odaklanmayı koru
                    _barcodeFocusNode.requestFocus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Sil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.summarize, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Talep Özeti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ürün listesi
                Column(
                  children: _requestedItems.entries.map((entry) {
                    final item = _requestItems.firstWhere(
                      (i) => i.stokkod == entry.key,
                      orElse: () => RequestItem(
                        id: '',
                        stokad: '',
                        stokkod: '',
                        kalanmiktar: 0,
                        fiyat: 0,
                        talepedilenMiktar: 0,
                        toplamTutar: 0,
                        date: DateTime.now(),
                        department: '',
                      ),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.stokad,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Stok: ${item.stokkod}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${entry.value} adet',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'tr_TR',
                                symbol: '₺',
                              ).format(item.toplamTutar),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                flex: 7,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainWidget();
  }

  Widget _buildRequestListWidget() {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: _requestItems.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz talep edilen ürün yok',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Arama butonuna basarak ürünleri yükleyin ve talep edin',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: _requestItems.length,
                itemBuilder: (context, index) {
                  final item = _requestItems[index];
                  final requestedQuantity = _requestedItems[item.stokkod] ?? 0;
                  final isRequested = requestedQuantity > 0;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 0,
                          top: 12,
                          bottom: 12,
                        ),
                        child: Row(
                          children: [
                            // Main content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    item.stokad,
                                    style: TextStyle(
                                      color: isRequested ? Colors.green : null,
                                      fontWeight: isRequested
                                          ? FontWeight.bold
                                          : null,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Stok Kodu: ${item.stokkod}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Miktar bilgileri
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isRequested
                                              ? Colors.green.shade100
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: isRequested
                                                ? Colors.green.shade300
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$requestedQuantity/${item.kalanmiktar}',
                                          style: TextStyle(
                                            color: isRequested
                                                ? Colors.green.shade800
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '= $requestedQuantity',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Toplam tutar
                                  Text(
                                    'Toplam: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(item.toplamTutar)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Buttons - Column with fixed width, right aligned
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Düzelt button
                                  _buildDuzeltButton(item.stokkod, item.stokad),
                                  const SizedBox(height: 6),
                                  // Sil button
                                  _buildSilButton(
                                    item.stokkod,
                                    item.stokad,
                                    isRequested,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider between items
                      if (index < _requestItems.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSearchButtonWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _showProductSelectionDialog,
          icon: const Icon(Icons.search, size: 20),
          label: const Text('Ürün Seçiniz', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildSelectionCardsWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // First row: Date and Department
          Row(
            children: [
              // Date Selection
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Tarih Seçiniz',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'tr_TR',
                            ).format(_selectedDate),
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Department Selection
              Expanded(
                child: Card(
                  color: _selectedDepartment != null
                      ? Colors.blue.shade50
                      : null,
                  child: InkWell(
                    onTap: _selectDepartment,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Departman Seçiniz',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.business,
                            size: 20,
                            color: _selectedDepartment != null
                                ? Colors.blue.shade700
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedDepartment?.ad ?? 'Seçiniz',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: _selectedDepartment != null
                                      ? FontWeight.bold
                                      : null,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second row: Alan/Servis and Şube
          Row(
            children: [
              // Alan/Servis
              Expanded(
                child: Card(
                  color: _selectedAlanServis != null
                      ? Colors.green.shade50
                      : null,
                  child: InkWell(
                    onTap: _selectAlanServis,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Alan/Servis',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.location_on,
                            size: 20,
                            color: _selectedAlanServis != null
                                ? Colors.green.shade700
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAlanServis?.ad ?? 'Seçiniz',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: _selectedAlanServis != null
                                      ? FontWeight.bold
                                      : null,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Şube Selection
              Expanded(
                child: Card(
                  color: _selectedSube != null ? Colors.orange.shade50 : null,
                  child: InkWell(
                    onTap: _selectSube,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Şube Seçiniz',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.store,
                            size: 20,
                            color: _selectedSube != null
                                ? Colors.orange.shade700
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedSube?.ad ?? 'Seçiniz',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: _selectedSube != null
                                      ? FontWeight.bold
                                      : null,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainWidget() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Geri',
          ),
          // Lazer okuyucu TextField
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(right: 5, left: 5),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _manualBarcodeController,
                focusNode: _barcodeFocusNode,
                keyboardType: TextInputType.none,
                textInputAction: TextInputAction.none,
                enableInteractiveSelection: false,
                showCursor: false,
                readOnly: false,
                decoration: const InputDecoration(
                  hintText: 'Lazer ile stok kodu okutun...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  // Lazer okuyucu verisi kontrolü
                  log('TextField değişti: $value');

                  if (value.endsWith('\n')) {
                    final barcode = value.replaceAll('\n', '').trim();
                    if (barcode.isNotEmpty) {
                      log('Lazer okuyucu stok kodu tespit edildi: $barcode');
                      _processBarcode(barcode);
                      _manualBarcodeController.clear();
                      // Odaklanmayı koru
                      _barcodeFocusNode.requestFocus();
                    }
                  }
                },
                onSubmitted: (value) {
                  // Enter tuşu işleme
                  if (value.isNotEmpty) {
                    log('Manuel giriş stok kodu: $value');
                    _processBarcode(value);
                    _manualBarcodeController.clear();
                    // Odaklanmayı koru
                    _barcodeFocusNode.requestFocus();
                  }
                },
              ),
            ),
          ),

          // Kamera ile barkod okuma butonu
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: 'Kamera ile Tara',
          ),
          // Arama butonu
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showProductSelectionDialog,
            tooltip: 'Ürün Seçiniz',
          ),
        ],
      ),

      body: Column(
        children: [
          _buildSelectionCardsWidget(),
          _buildSearchButtonWidget(),
          _buildRequestListWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestedItems.isNotEmpty ? _showSummaryDialog : null,
        icon: const Icon(Icons.check),
        label: const Text('KAYDET'),
      ),
    );
  }
}

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  Barcode? result;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _isCameraInitialized = false;
  bool _isDisposed = false;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (!_isDisposed && controller != null) {
      if (Platform.isAndroid) {
        controller!.pauseCamera();
      }
      controller!.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Kodu Tara'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    if (result != null)
                      Text(
                        'Stok Kodu: ${result!.code}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Stok kodunu kameraya gösterin',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          margin: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: _isCameraInitialized && !_isDisposed
                                ? () async {
                                    try {
                                      await controller?.toggleFlash();
                                      if (mounted) setState(() {});
                                    } catch (e) {
                                      log('Flash toggle error: $e');
                                    }
                                  }
                                : null,
                            child: _isCameraInitialized
                                ? FutureBuilder(
                                    future: controller?.getFlashStatus(),
                                    builder: (context, snapshot) {
                                      return Text(
                                        'Flash: ${snapshot.data ?? 'Bilinmiyor'}',
                                      );
                                    },
                                  )
                                : const Text('Flash: Yükleniyor...'),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: _isCameraInitialized && !_isDisposed
                                ? () async {
                                    try {
                                      await controller?.flipCamera();
                                      if (mounted) setState(() {});
                                    } catch (e) {
                                      log('Camera flip error: $e');
                                    }
                                  }
                                : null,
                            child: _isCameraInitialized
                                ? FutureBuilder(
                                    future: controller?.getCameraInfo(),
                                    builder: (context, snapshot) {
                                      if (snapshot.data != null) {
                                        return Text(
                                          'Kamera: ${snapshot.data!.name}',
                                        );
                                      } else {
                                        return const Text(
                                          'Kamera: Yükleniyor...',
                                        );
                                      }
                                    },
                                  )
                                : const Text('Kamera: Yükleniyor...'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          margin: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: _isCameraInitialized && !_isDisposed
                                ? () async {
                                    try {
                                      await controller?.pauseCamera();
                                    } catch (e) {
                                      log('Camera pause error: $e');
                                    }
                                  }
                                : null,
                            child: const Text(
                              'Duraklat',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: _isCameraInitialized && !_isDisposed
                                ? () async {
                                    try {
                                      await controller?.resumeCamera();
                                    } catch (e) {
                                      log('Camera resume error: $e');
                                    }
                                  }
                                : null,
                            child: const Text(
                              'Devam Et',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea =
        (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;
    // To ensure the Scanner view is properly sizes after rotation
    // we need to listen for Flutter SizeChanged notification and update controller
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
        borderColor: Colors.red,
        borderRadius: 10,
        borderLength: 30,
        borderWidth: 10,
        cutOutSize: scanArea,
      ),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    if (_isDisposed) return;

    setState(() {
      this.controller = controller;
      _isCameraInitialized = true;
    });

    controller.scannedDataStream.listen((scanData) {
      if (_isDisposed) return;

      setState(() {
        result = scanData;
      });

      // Stok kodu okunduğunda ana sayfaya dön ve işle
      if (result != null && result!.code != null && mounted) {
        Navigator.pop(context, result!.code);
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    log('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kamera izni gerekli')));
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    if (controller != null) {
      controller!.pauseCamera();
      controller = null;
    }
    super.dispose();
  }
}
