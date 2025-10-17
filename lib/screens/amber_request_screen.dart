import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../models/department.dart';
import '../models/sube.dart';
import '../models/stok_master.dart';
import '../models/amber_talep_item.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AmberRequestScreen extends StatefulWidget {
  const AmberRequestScreen({super.key});

  @override
  State<AmberRequestScreen> createState() => _AmberRequestScreenState();
}

class _AmberRequestScreenState extends State<AmberRequestScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment; // Anadepo = true olanlar
  Department? _selectedAlanServis; // Anadepo = false olanlar
  Sube? _selectedSube; // Şube

  List<StokMaster> _allStoklar = []; // Tüm stoklar (ilk açılışta yüklenir)
  final List<AmberTalepItem> _talepItems = []; // Talep edilen ürünler

  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  List<Department> _departments = []; // Anadepo = true olanlar
  List<Department> _alanServisList = []; // Anadepo = false olanlar
  List<Sube> _subeler = []; // Şubeler

  bool _isLoadingStoklar = false;
  bool _isSaving = false;

  String? _token;
  int? _dbId;

  @override
  void initState() {
    super.initState();

    // Lazer okuyucu için odaklanma
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final selectedDb = Provider.of<SelectedDatabaseProvider>(
      context,
      listen: false,
    ).selectedDatabase;
    if (selectedDb != null) {
      _dbId = selectedDb.id;
    }

    // Token'ı StorageService'den al
    _token = await StorageService.getToken();

    if (!mounted) return;

    // Departmanları, şubeleri ve stokları yükle
    if (_token != null && _dbId != null) {
      await Future.wait([_loadDepartments(), _loadSubeler(), _loadStoklar()]);
    }
  }

  Future<void> _loadStoklar() async {
    if (_allStoklar.isNotEmpty) return; // Zaten yüklenmiş

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
        log('${_allStoklar.length} stok yüklendi');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stok yükleme hatası: ${response.message ?? 'Bilinmeyen hata'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      log('Stok yükleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stok yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStoklar = false;
        });
      }
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final response = await ApiService.getAmberDepartments(
        _token!,
        _dbId!,
        'Departman',
        false,
      );

      if (response.isSucceded) {
        setState(() {
          _departments = response.value
              .where((d) => d.anadepo == true)
              .toList();
          _alanServisList = response.value
              .where((d) => d.anadepo == false)
              .toList();

          // İlk departmanı ve alan/servisi otomatik seç
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

          // İlk şubeyi otomatik seç
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

  @override
  void dispose() {
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
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
                minimumDate: DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  1,
                ), // Bu ayın ilk günü
                maximumDate: DateTime(
                  DateTime.now().year + 1,
                  12,
                  31,
                ), // Gelecek yılın sonu
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
                      subtitle: Text('Kod: ${department.kod}'),
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
                      subtitle: Text('Kod: ${alanServis.kod}'),
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

  void _showProductSelectionDialog() {
    if (_isLoadingStoklar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stoklar yükleniyor, lütfen bekleyiniz...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_allStoklar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok listesi boş'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String searchQuery = '';
    List<StokMaster> filteredStoklar = _allStoklar;
    bool isLoadingProduct = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Ürün seçimi fonksiyonu
          Future<void> processStokSelection(StokMaster stok) async {
            if (_selectedDepartment == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lütfen önce departman seçiniz'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Loading başlat
            setDialogState(() {
              isLoadingProduct = true;
            });

            try {
              final now = DateTime.now();
              final tarih1 = DateTime(now.year, now.month, 1).toIso8601String();
              final tarih2 = now.toIso8601String();

              log('Stok fiyat bilgisi alınıyor: ${stok.genelKod}');
              final response = await ApiService.getStokBirimFiyat(
                _token!,
                _dbId!,
                stok.genelKod,
                tarih1,
                tarih2,
                _selectedDepartment!.kod,
              );

              log(
                'API Response: ${response.isSucceded}, Value count: ${response.value.length}',
              );

              if (response.isSucceded && response.value.isNotEmpty) {
                final fiyatBilgisi = response.value.first;
                log(
                  'Fiyat bilgisi: Kalan=${fiyatBilgisi.kalanMiktar}, Fiyat=${fiyatBilgisi.birimFiyat}',
                );

                // Kalan miktar kontrolü
                if (fiyatBilgisi.kalanMiktar <= 0) {
                  if (mounted) {
                    setDialogState(() {
                      isLoadingProduct = false;
                    });
                    // Dialog olarak göster
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: Colors.red[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stok.ad,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Bu ürün için kalan miktar sıfırdan küçük: ${fiyatBilgisi.kalanMiktar}',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Tamam'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                // Dialog'u kapat ve miktar girme dialogunu aç
                if (mounted) {
                  Navigator.pop(context); // Ürün seçim dialog'unu kapat
                  _showQuantityDialog(
                    stok,
                    fiyatBilgisi.kalanMiktar,
                    fiyatBilgisi.birimFiyat,
                    fiyatBilgisi.birim,
                  );
                }
              } else {
                if (mounted) {
                  setDialogState(() {
                    isLoadingProduct = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Stok fiyat bilgisi alınamadı: ${response.message ?? 'Bilinmeyen hata'}',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              log('Hata: $e');
              if (mounted) {
                setDialogState(() {
                  isLoadingProduct = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Ürün Seçiniz',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${filteredStoklar.length} ürün',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Ürün adı, kod veya barkod ile arayın...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[600],
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      searchQuery = '';
                                      filteredStoklar = _allStoklar;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            searchQuery = value.toLowerCase();
                            filteredStoklar = _allStoklar.where((stok) {
                              return stok.ad.toLowerCase().contains(
                                    searchQuery,
                                  ) ||
                                  stok.genelKod.toLowerCase().contains(
                                    searchQuery,
                                  ) ||
                                  stok.barkod1.toLowerCase().contains(
                                    searchQuery,
                                  );
                            }).toList();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Product list
                Expanded(
                  child: filteredStoklar.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ürün bulunamadı',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Farklı anahtar kelimeler deneyin',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStoklar.length,
                          itemBuilder: (context, index) {
                            final stok = filteredStoklar[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                elevation: 1,
                                child: InkWell(
                                  onTap: isLoadingProduct
                                      ? null
                                      : () {
                                          processStokSelection(stok);
                                        },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Product icon
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.inventory,
                                            color: Colors.blue[600],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Product info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stok.ad,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      stok.kod,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (stok.barkod1.isNotEmpty)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.green[100],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Barkod',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              Colors.green[700],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${stok.anabirim} • ${stok.genelKod}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Arrow icon veya loading
                                        isLoadingProduct
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey[400],
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _processBarcode(String barcode) {
    // Barkod ile ürün ara
    final foundStok = _allStoklar.firstWhere(
      (stok) => stok.barkod1 == barcode,
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

    if (foundStok.id != 0) {
      _processStokSelection(foundStok);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod bulunamadı: $barcode'),
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

    try {
      final now = DateTime.now();
      final tarih1 = DateTime(now.year, now.month, 1).toIso8601String();
      final tarih2 = now.toIso8601String();

      final response = await ApiService.getStokBirimFiyat(
        _token!,
        _dbId!,
        stok.genelKod,
        tarih1,
        tarih2,
        _selectedDepartment!.kod,
      );

      if (response.isSucceded && response.value.isNotEmpty) {
        final fiyatBilgisi = response.value.first;

        // Kalan miktar kontrolü
        if (fiyatBilgisi.kalanMiktar <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Kalan miktar sıfırdan küçük: ${fiyatBilgisi.kalanMiktar}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

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
            SnackBar(
              content: Text(
                'Stok fiyat bilgisi alınamadı: ${response.message ?? 'Bilinmeyen hata'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
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
    double kalanMiktar, // API'den gelen toplam stok miktarı
    double birimFiyat,
    String birim,
  ) {
    final TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final miktar = int.tryParse(quantityController.text) ?? 0;
          final isValidQuantity = miktar > 0 && miktar <= kalanMiktar;

          return AlertDialog(
            title: Text('Miktar Gir - ${stok.ad}'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ürün bilgileri - Kompakt
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stok Kodu: ${stok.genelKod}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Kalan miktar ve birim fiyat yan yana
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Kalan: $kalanMiktar $birim',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Fiyat: ${birimFiyat.toStringAsFixed(2)} ₺',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Miktar girişi - Kompakt
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            readOnly: true,
                            showCursor: true,
                            enableInteractiveSelection: true,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Miktar',
                              hintText: 'Miktar giriniz',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Max: $kalanMiktar $birim',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sonuç gösterimi - Kompakt
                    if (quantityController.text.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isValidQuantity
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isValidQuantity
                                ? Colors.green[200]!
                                : Colors.red[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sonuç: $miktar $birim',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isValidQuantity
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (miktar > 0) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tutar: ${(miktar * birimFiyat).toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sayısal klavye
                    _buildQuantityKeyboard(quantityController, setDialogState),
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
                              _addTalepItem(
                                stok,
                                miktar,
                                birimFiyat,
                                birim,
                                kalanMiktar,
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Ekle'),
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

  // Sayısal klavye
  Widget _buildQuantityKeyboard(
    TextEditingController quantityController,
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
              _buildQuantityNumberButton(
                '1',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '2',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '3',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuantityNumberButton(
                '4',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '5',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '6',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuantityNumberButton(
                '7',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '8',
                quantityController,
                setDialogState,
              ),
              _buildQuantityNumberButton(
                '9',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dördüncü satır: Temizle, 0, Sil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuantityActionButton('C', () {
                quantityController.text = '';
                quantityController.selection = TextSelection.fromPosition(
                  TextPosition(offset: quantityController.text.length),
                );
                setDialogState(() {});
              }),
              _buildQuantityNumberButton(
                '0',
                quantityController,
                setDialogState,
              ),
              _buildQuantityActionButton('⌫', () {
                if (quantityController.text.isNotEmpty) {
                  quantityController.text = quantityController.text.substring(
                    0,
                    quantityController.text.length - 1,
                  );
                }
                quantityController.selection = TextSelection.fromPosition(
                  TextPosition(offset: quantityController.text.length),
                );
                setDialogState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityNumberButton(
    String number,
    TextEditingController quantityController,
    StateSetter setDialogState,
  ) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          quantityController.text += number;
          quantityController.selection = TextSelection.fromPosition(
            TextPosition(offset: quantityController.text.length),
          );
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

  Widget _buildQuantityActionButton(String text, VoidCallback onPressed) {
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

  void _addTalepItem(
    StokMaster stok,
    int miktar,
    double birimFiyat,
    String birim,
    double toplamMiktar, // API'den gelen kalan miktar (stoktaki toplam)
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
          kalanMiktar: toplamMiktar, // API'den gelen toplam stok miktarı
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
            kalanMiktar: toplamMiktar, // API'den gelen toplam stok miktarı
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

  void _removeTalepItem(int index) {
    setState(() {
      _talepItems.removeAt(index);
    });
  }

  // Düzeltme dialogu
  void _showEditQuantityDialog(AmberTalepItem item, int index) {
    final TextEditingController quantityController = TextEditingController();
    // Boş başlat

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final miktar = int.tryParse(quantityController.text) ?? 0;
          final isValidQuantity = miktar > 0 && miktar <= item.kalanMiktar;
          final isEmpty = quantityController.text.trim().isEmpty;

          return AlertDialog(
            title: Text('Miktar Düzelt - ${item.stokAd}'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ürün bilgileri
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stok Kodu: ${item.stokkod}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mevcut: ${item.miktar} ${item.birim}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Max: ${item.kalanMiktar.toInt()} ${item.birim}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Miktar girişi
                    TextField(
                      controller: quantityController,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Yeni Miktar',
                        hintText: 'Miktar giriniz',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sonuç gösterimi
                    if (quantityController.text.isNotEmpty && miktar > 0) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isValidQuantity
                              ? Colors.green[50]
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isValidQuantity
                                ? Colors.green[200]!
                                : Colors.red[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sonuç: $miktar ${item.birim}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isValidQuantity
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (miktar > 0) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tutar: ${(miktar * item.birimFiyat).toStringAsFixed(2)} ₺',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sayısal klavye
                    _buildEditQuantityKeyboard(
                      quantityController,
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
                              _updateTalepItemQuantity(index, miktar);
                              Navigator.pop(context);
                            }
                          : () {
                              // Uyarı göster
                              String message;
                              if (isEmpty) {
                                message = 'Lütfen miktar giriniz';
                              } else if (miktar <= 0) {
                                message = 'Miktar 0\'dan büyük olmalıdır';
                              } else {
                                message =
                                    'Miktar maksimum ${item.kalanMiktar.toInt()} olabilir';
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValidQuantity
                            ? Colors.green
                            : Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isValidQuantity ? 'Kaydet' : 'Uyar'),
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

  // Sayısal klavye - Düzeltme için
  Widget _buildEditQuantityKeyboard(
    TextEditingController quantityController,
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
              _buildEditQuantityNumberButton(
                '1',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '2',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '3',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEditQuantityNumberButton(
                '4',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '5',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '6',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEditQuantityNumberButton(
                '7',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '8',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityNumberButton(
                '9',
                quantityController,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dördüncü satır: Temizle, 0, Sil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEditQuantityActionButton('C', () {
                quantityController.text = '';
                quantityController.selection = TextSelection.fromPosition(
                  TextPosition(offset: quantityController.text.length),
                );
                setDialogState(() {});
              }),
              _buildEditQuantityNumberButton(
                '0',
                quantityController,
                setDialogState,
              ),
              _buildEditQuantityActionButton('⌫', () {
                if (quantityController.text.isNotEmpty) {
                  quantityController.text = quantityController.text.substring(
                    0,
                    quantityController.text.length - 1,
                  );
                }
                quantityController.selection = TextSelection.fromPosition(
                  TextPosition(offset: quantityController.text.length),
                );
                setDialogState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditQuantityNumberButton(
    String number,
    TextEditingController quantityController,
    StateSetter setDialogState,
  ) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          quantityController.text += number;
          quantityController.selection = TextSelection.fromPosition(
            TextPosition(offset: quantityController.text.length),
          );
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

  Widget _buildEditQuantityActionButton(String text, VoidCallback onPressed) {
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

  void _updateTalepItemQuantity(int index, int newQuantity) {
    if (index >= 0 && index < _talepItems.length) {
      setState(() {
        final item = _talepItems[index];
        _talepItems[index] = AmberTalepItem(
          stokkod: item.stokkod,
          stokAd: item.stokAd,
          birim: item.birim,
          barkod: item.barkod,
          miktar: newQuantity,
          birimFiyat: item.birimFiyat,
          tutar: newQuantity * item.birimFiyat,
          kalanMiktar: item.kalanMiktar,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_talepItems[index].stokAd} miktarı güncellendi'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveAmberTalep() async {
    if (_talepItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talep edilecek ürün bulunamadı'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

    setState(() {
      _isSaving = true;
    });

    try {
      final tarih = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final satirlar = _talepItems.map((item) => item.toJson()).toList();

      // JSON'u log olarak yazdır
      final requestData = {
        'db_Id': _dbId,
        'Tarih': tarih,
        'Depo': _selectedDepartment!.kod,
        'AlanServis': _selectedAlanServis!.kod,
        'Sirketkod': _selectedSube!.kod,
        'Fisno': 0,
        'Fistipi': 'J',
        'MatbuFisno': 0,
        'Satirlar': satirlar,
      };

      // JSON'u düzgün formatla ve logla
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String prettyJson = encoder.convert(requestData);

      log('=== AMBER TALEP KAYDET JSON ===');
      log('$prettyJson');
      log('=== END AMBER TALEP JSON ===');

      final response = await ApiService.saveAmberTalep(
        _token!,
        _dbId!,
        tarih,
        _selectedDepartment!.kod,
        _selectedAlanServis!.kod,
        _selectedSube!.kod,
        satirlar,
      );

      if (response['isSucceded'] == true) {
        final fisno = response['value']['value'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Talep başarıyla kaydedildi. Fiş No: $fisno'),
            backgroundColor: Colors.green,
          ),
        );

        // Listeyi temizle
        setState(() {
          _talepItems.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kaydetme hatası: ${response['message'] ?? 'Bilinmeyen hata'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydetme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showRefreshConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekranı Temizle'),
        content: const Text('Tüm veriler silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _talepItems.clear();
                _selectedDate = DateTime.now();
                _selectedDepartment = null;
                _selectedAlanServis = null;
                _selectedSube = null;
              });
              Navigator.pop(context);
              _loadInitialData(); // Verileri yeniden yükle
            },
            child: const Text('Evet, Temizle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        actions: [
          // Geri butonu
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
                  hintText: 'Lazer ile barkod okutun...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  // Lazer okuyucu verisi kontrolü
                  if (value.endsWith('\n')) {
                    final barcode = value.replaceAll('\n', '').trim();
                    if (barcode.isNotEmpty) {
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
          // Manuel barkod ekleme butonu
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showProductSelectionDialog,
            tooltip: 'Ürün Seçiniz',
          ),
          // Refresh butonu
          IconButton(
            onPressed: _showRefreshConfirmation,
            icon: const Icon(Icons.refresh),
            tooltip: 'Ekranı Temizle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Seçim kartları
          _buildSelectionCardsWidget(),

          // Talep listesi
          Expanded(
            child: _talepItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz talep edilen ürün yok',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ürün seçiniz butonuna basarak ürün seçebilirsiniz',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Başlık
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Talep Edilen Ürünler (${_talepItems.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Uyarı mesajı
                      if (_talepItems.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border(
                              top: BorderSide(
                                color: Colors.red[200]!,
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: Colors.red[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.red[600],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'DİKKAT: Kaydetmeyi unutmayınız!!!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Liste
                      Expanded(
                        child: ListView.builder(
                          itemCount: _talepItems.length,
                          itemBuilder: (context, index) {
                            final item = _talepItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                title: Text(
                                  item.stokAd,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Stok Kodu: ${item.stokkod}'),
                                    Text('Birim: ${item.birim}'),
                                    const SizedBox(height: 4),
                                    // Miktar gösterimi: girilenmiktar/toplammiktar
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.blue[200]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Miktar: ${item.miktar}/${item.kalanMiktar.toInt()} ${item.birim}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Fiyat hesaplama: girilenmiktar*birimfiyat = toplamfiyat
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.green[200]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${item.miktar} × ${item.birimFiyat.toStringAsFixed(2)} = ${item.tutar.toStringAsFixed(2)} ₺',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Düzelt button
                                    SizedBox(
                                      width: 80,
                                      height: 28,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _showEditQuantityDialog(
                                              item,
                                              index,
                                            ),
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text(
                                          'Düzelt',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade700,
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Sil button
                                    SizedBox(
                                      width: 80,
                                      height: 28,
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _removeTalepItem(index),
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Sil',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade700,
                                          foregroundColor: Colors.white,
                                          elevation: 1,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                            horizontal: 4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: _talepItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveAmberTalep,
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
            )
          : null,
    );
  }

  Widget _buildSelectionCardsWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // İlk satır: Tarih ve Departman
          Row(
            children: [
              // Tarih seçimi
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Tarih',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Departman seçimi
              Expanded(
                child: Card(
                  color: _selectedDepartment != null ? Colors.blue[50] : null,
                  child: InkWell(
                    onTap: _selectDepartment,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            color: _selectedDepartment != null
                                ? Colors.blue
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Departman',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedDepartment?.ad ?? 'Seçiniz',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _selectedDepartment != null
                                        ? Colors.blue[800]
                                        : Colors.grey[600],
                                    fontWeight: _selectedDepartment != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedDepartment != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kod: ${_selectedDepartment!.kod}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.blue[600],
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: Alan/Servis ve Şube
          Row(
            children: [
              // Alan/Servis seçimi
              Expanded(
                child: Card(
                  color: _selectedAlanServis != null ? Colors.green[50] : null,
                  child: InkWell(
                    onTap: _selectAlanServis,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.room_service,
                            color: _selectedAlanServis != null
                                ? Colors.green
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Alan/Servis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedAlanServis?.ad ?? 'Seçiniz',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _selectedAlanServis != null
                                        ? Colors.green[800]
                                        : Colors.grey[600],
                                    fontWeight: _selectedAlanServis != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedAlanServis != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kod: ${_selectedAlanServis!.kod}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.green[600],
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
                ),
              ),
              const SizedBox(width: 8),
              // Şube seçimi
              Expanded(
                child: Card(
                  color: _selectedSube != null ? Colors.orange[50] : null,
                  child: InkWell(
                    onTap: _selectSube,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            color: _selectedSube != null
                                ? Colors.orange
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Şube',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedSube?.ad ?? 'Seçiniz',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _selectedSube != null
                                        ? Colors.orange[800]
                                        : Colors.grey[600],
                                    fontWeight: _selectedSube != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_selectedSube != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kod: ${_selectedSube!.kod}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.orange[600],
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
                ),
              ),
            ],
          ),
        ],
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
        title: const Text('Barkod Tara'),
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
                        'Barkod: ${result!.code}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Barkodu kameraya gösterin',
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

      // Barkod okunduğunda ana sayfaya dön ve işle
      if (result != null && result!.code != null) {
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
      controller!.dispose();
      controller = null;
    }
    super.dispose();
  }
}
