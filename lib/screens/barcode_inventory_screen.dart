import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/inventory_item.dart';
import '../models/department.dart';
import '../models/sayim_item.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class BarcodeInventoryScreen extends StatefulWidget {
  const BarcodeInventoryScreen({super.key});

  @override
  State<BarcodeInventoryScreen> createState() => _BarcodeInventoryScreenState();
}

class _BarcodeInventoryScreenState extends State<BarcodeInventoryScreen> {
  DateTime _selectedDate = DateTime.now();
  Department? _selectedDepartment;
  // Sabit tip - S (Stok)
  List<InventoryItem> _inventoryItems = [];
  List<Department> _departments = [];
  List<SayimItem> _sayimItems = [];
  bool _isLoadingDepartments = false;
  bool _isLoadingSayim = false;
  final Map<String, int> _countedItems = {};
  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(
    debugLabel: 'BarcodeInput',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';

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
      _loadDepartments();
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoadingDepartments = true;
    });

    try {
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();

      if (databaseProvider.selectedDatabase != null && token != null) {
        final response = await ApiService.getDepartments(
          token,
          databaseProvider.selectedDatabase!.id,
        );

        if (response.isSucceded) {
          setState(() {
            _departments = response.value;
            if (response.value.isNotEmpty) {
              _selectedDepartment = response.value.first;
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Departman yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoadingDepartments = false;
    });
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Departman Seçin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _departments
                      .map(
                        (dept) => Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedDepartment = dept;
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedDepartment?.id == dept.id
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: _selectedDepartment?.id == dept.id
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Radio<Department>(
                                    value: dept,
                                    groupValue: _selectedDepartment,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDepartment = value!;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dept.ad,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          'Kod: ${dept.kod}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInventory() async {
    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce departman seçiniz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingSayim = true;
    });

    try {
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();

      if (databaseProvider.selectedDatabase != null && token != null) {
        // Tarihi yyyy-MM-dd formatına çevir
        final tarih = DateFormat('yyyy-MM-dd').format(_selectedDate);

        final response = await ApiService.getSayimListe(
          token,
          databaseProvider.selectedDatabase!.id,
          tarih,
          _selectedDepartment!.kod,
        );

        if (response.isSucceded) {
          setState(() {
            _sayimItems = response.value;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sayım listesi alınamadı: ${response.message ?? 'Bilinmeyen hata'}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sayım yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoadingSayim = false;
    });
  }

  void _processBarcode(String barcode) {
    // Barkod var mı kontrol et
    final existingItemIndex = _inventoryItems.indexWhere(
      (item) => item.barcode == barcode,
    );

    if (existingItemIndex != -1) {
      // Mevcut ürün - miktarını artır
      setState(() {
        _countedItems[barcode] = (_countedItems[barcode] ?? 0) + 1;
        // Ürünü en üste taşı
        _moveItemToTop(barcode);
      });
    } else {
      // Yeni ürün - listeye ekle
      final newItem = InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        barcode: barcode,
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment?.ad ?? '',
      );

      setState(() {
        _inventoryItems.insert(0, newItem);
        _countedItems[barcode] = 1;
      });
    }

    // Odaklanmayı koru
    _barcodeFocusNode.requestFocus();
  }

  void _moveItemToTop(String barcode) {
    // Barkod ile eşleşen ürünü bul ve en üste taşı
    final itemIndex = _inventoryItems.indexWhere(
      (item) => item.barcode == barcode,
    );
    if (itemIndex != -1) {
      final item = _inventoryItems.removeAt(itemIndex);
      _inventoryItems.insert(0, item);
      setState(() {});
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

  void _showProductQuantityDialog(String barcode, String itemName) {
    // Mevcut miktarı al
    final currentQuantity = _countedItems[barcode] ?? 0;
    final TextEditingController addQuantityController = TextEditingController();
    final TextEditingController totalQuantityController =
        TextEditingController();
    final FocusNode addQuantityFocusNode = FocusNode();
    final FocusNode totalQuantityFocusNode = FocusNode();
    bool isAddQuantityFocused = true;

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

          return AlertDialog(
            title: Text('Miktar Düzelt - Barkod: $barcode'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mevcut miktar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        'Mevcut Miktar: $currentQuantity',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // İki input alanı yan yana
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
                    const SizedBox(height: 16),

                    // Sonuç gösterimi
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Sonuç: $displayTotal',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (displayAdd != 0 &&
                              (isAddQuantityFocused
                                  ? addQuantity > 0
                                  : totalQuantity > 0)) ...[
                            const SizedBox(height: 4),
                            Text(
                              displayAdd > 0
                                  ? 'Eklenecek: +$displayAdd'
                                  : 'Çıkarılacak: $displayAdd',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: displayAdd > 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

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
                      onPressed: () {
                        if (finalQuantity >= 0) {
                          setState(() {
                            _countedItems[barcode] = finalQuantity;
                            // Ürünü en üste taşı
                            _moveItemToTop(barcode);
                          });
                          Navigator.pop(context);
                          // Odaklanmayı koru
                          _barcodeFocusNode.requestFocus();
                        }
                      },
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

  Widget _buildTripleModeKeyboard(
    TextEditingController barcodeController,
    TextEditingController addQuantityController,
    TextEditingController totalQuantityController,
    bool isBarcodeFocused,
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
              _buildTripleModeNumberButton(
                '1',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '2',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '3',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
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
              _buildTripleModeNumberButton(
                '4',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '5',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '6',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
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
              _buildTripleModeNumberButton(
                '7',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '8',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildTripleModeNumberButton(
                '9',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
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
                if (isBarcodeFocused) {
                  barcodeController.text = '';
                  barcodeController.selection = TextSelection.fromPosition(
                    TextPosition(offset: barcodeController.text.length),
                  );
                } else if (isAddQuantityFocused) {
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
              _buildTripleModeNumberButton(
                '0',
                barcodeController,
                addQuantityController,
                totalQuantityController,
                isBarcodeFocused,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildActionButton('⌫', () {
                if (isBarcodeFocused) {
                  if (barcodeController.text.isNotEmpty) {
                    barcodeController.text = barcodeController.text.substring(
                      0,
                      barcodeController.text.length - 1,
                    );
                  }
                  barcodeController.selection = TextSelection.fromPosition(
                    TextPosition(offset: barcodeController.text.length),
                  );
                } else if (isAddQuantityFocused) {
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

  Widget _buildTripleModeNumberButton(
    String number,
    TextEditingController barcodeController,
    TextEditingController addQuantityController,
    TextEditingController totalQuantityController,
    bool isBarcodeFocused,
    bool isAddQuantityFocused,
    StateSetter setDialogState,
  ) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (isBarcodeFocused) {
            // Barkod girişi
            barcodeController.text += number;
            barcodeController.selection = TextSelection.fromPosition(
              TextPosition(offset: barcodeController.text.length),
            );
          } else if (isAddQuantityFocused) {
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

  void _showManualBarcodeDialog() {
    final TextEditingController barcodeInputController =
        TextEditingController();
    final TextEditingController addQuantityController = TextEditingController();
    final TextEditingController totalQuantityController =
        TextEditingController();
    final FocusNode barcodeFocusNode = FocusNode();
    final FocusNode addQuantityFocusNode = FocusNode();
    final FocusNode totalQuantityFocusNode = FocusNode();
    bool isBarcodeFocused = true;
    bool isAddQuantityFocused = true;

    // Başlangıçta barkod alanına odaklan
    barcodeFocusNode.addListener(() {
      if (barcodeFocusNode.hasFocus) {
        isBarcodeFocused = true;
      }
    });

    addQuantityFocusNode.addListener(() {
      if (addQuantityFocusNode.hasFocus) {
        isBarcodeFocused = false;
        isAddQuantityFocused = true;
      }
    });

    totalQuantityFocusNode.addListener(() {
      if (totalQuantityFocusNode.hasFocus) {
        isBarcodeFocused = false;
        isAddQuantityFocused = false;
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentQuantity =
              _countedItems[barcodeInputController.text.trim()] ?? 0;
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

          return AlertDialog(
            title: const Text('Manuel Barkod Ekle'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barkod girişi
                    TextField(
                      controller: barcodeInputController,
                      focusNode: barcodeFocusNode,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: true,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isBarcodeFocused ? Colors.blue : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Barkod',
                        hintText: 'Barkod numarasını girin',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isBarcodeFocused ? Colors.blue : Colors.grey,
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste),
                          onPressed: () async {
                            final clipboardData = await Clipboard.getData(
                              'text/plain',
                            );
                            if (clipboardData?.text != null) {
                              barcodeInputController.text =
                                  clipboardData!.text!;
                              barcodeInputController
                                  .selection = TextSelection.fromPosition(
                                TextPosition(
                                  offset: barcodeInputController.text.length,
                                ),
                              );
                              setDialogState(() {});
                            }
                          },
                          tooltip: 'Yapıştır',
                        ),
                      ),
                      onTap: () {
                        setDialogState(() {
                          isBarcodeFocused = true;
                          barcodeFocusNode.requestFocus();
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mevcut miktar gösterimi
                    if (barcodeInputController.text.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'Mevcut Miktar: $currentQuantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                                isBarcodeFocused = false;
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
                                isBarcodeFocused = false;
                                isAddQuantityFocused = false;
                                totalQuantityFocusNode.requestFocus();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sonuç gösterimi
                    if (barcodeInputController.text.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Sonuç: $displayTotal',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (displayAdd != 0 &&
                                (isAddQuantityFocused
                                    ? addQuantity > 0
                                    : totalQuantity > 0)) ...[
                              const SizedBox(height: 4),
                              Text(
                                displayAdd > 0
                                    ? 'Eklenecek: +$displayAdd'
                                    : 'Çıkarılacak: $displayAdd',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: displayAdd > 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Özel sayısal klavye
                    _buildTripleModeKeyboard(
                      barcodeInputController,
                      addQuantityController,
                      totalQuantityController,
                      isBarcodeFocused,
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
                      onPressed: () {
                        final barcode = barcodeInputController.text.trim();
                        if (barcode.isNotEmpty && finalQuantity >= 0) {
                          // Barkod var mı kontrol et
                          final existingItemIndex = _inventoryItems.indexWhere(
                            (item) => item.barcode == barcode,
                          );

                          if (existingItemIndex != -1) {
                            // Mevcut ürün - miktarını güncelle
                            setState(() {
                              _countedItems[barcode] = finalQuantity;
                              // Ürünü en üste taşı
                              _moveItemToTop(barcode);
                            });
                          } else {
                            // Yeni ürün - listeye ekle
                            final newItem = InventoryItem(
                              id: DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              barcode: barcode,
                              name: '',
                              unit: 'Adet',
                              quantity: 0,
                              averagePrice: 0,
                              totalAmount: 0,
                              date: _selectedDate,
                              department: _selectedDepartment?.ad ?? '',
                            );

                            setState(() {
                              _inventoryItems.insert(0, newItem);
                              _countedItems[barcode] = finalQuantity;
                            });
                          }

                          Navigator.pop(context);
                          // Odaklanmayı koru
                          _barcodeFocusNode.requestFocus();
                        }
                      },
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

  void _showDeleteConfirmationDialog(String barcode, String itemName) {
    final currentQuantity = _countedItems[barcode] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme Onayı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Barkod: $barcode',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (itemName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ürün: $itemName'),
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
                'Mevcut Miktar: $currentQuantity',
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
                      _countedItems.remove(barcode);
                      // Eğer sayılan miktar yoksa, ürünü listeden de kaldır
                      if (_countedItems[barcode] == null) {
                        _inventoryItems.removeWhere(
                          (item) => item.barcode == barcode,
                        );
                      }
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
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.inventory, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Sayım Özeti',
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
                // Barkod listesi
                _countedItems.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text(
                            'Henüz sayım yapılmadı',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : Column(
                        children: _countedItems.entries.map((entry) {
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
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'Barkod: ${entry.key}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${entry.value} adet',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.green,
                                  ),
                                ),
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

  Widget _buildInventoryListWidget() {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: _sayimItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isLoadingSayim
                                ? 'Sayım listesi yükleniyor...'
                                : 'Listele butonuna basarak sayım listesini yükleyin',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 150),
                      itemCount: _sayimItems.length,
                      itemBuilder: (context, index) {
                        final item = _sayimItems[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Üst satır - Stok kodu ve barkod
                              Row(
                                children: [
                                  if (item.sayimStokkod.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Stok: ${item.sayimStokkod}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Barkod: ${item.sayimBarkod}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Orta satır - Ürün adı
                              if (item.masterAd != null &&
                                  item.masterAd!.isNotEmpty)
                                Text(
                                  item.masterAd!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                              const SizedBox(height: 8),

                              // Alt satır - Miktar ve birim
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Miktar: ${item.sayimMiktar.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.sayimAltbirim.isNotEmpty)
                                    Text(
                                      item.sayimAltbirim,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
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

  Widget _buildListButtonWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isLoadingSayim ? null : _loadInventory,
          icon: _isLoadingSayim
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
          label: Text(
            _isLoadingSayim ? 'Yükleniyor...' : 'Listele',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCardsWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Date Selection
          Expanded(
            child: Card(
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Tarih Seçiniz',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Icon(Icons.calendar_today, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'tr_TR',
                        ).format(_selectedDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Department Selection
          Expanded(
            child: Card(
              child: InkWell(
                onTap: _selectDepartment,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Departman Seçiniz',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      _isLoadingDepartments
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.business, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        _selectedDepartment?.ad ?? 'Yükleniyor...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_selectedDepartment?.kod != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kod: ${_selectedDepartment!.kod}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
                  hintText: 'Lazer ile   barkod okutun...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  // Lazer okuyucu verisi kontrolü
                  print('TextField değişti: $value');

                  if (value.endsWith('\n')) {
                    final barcode = value.replaceAll('\n', '').trim();
                    if (barcode.isNotEmpty) {
                      print('Lazer okuyucu barkod tespit edildi: $barcode');
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
                    print('Manuel giriş barkod: $value');
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
            onPressed: _showManualBarcodeDialog,
            tooltip: 'Manuel Barkod Ekle',
          ),
        ],
      ),

      body: Column(
        children: [
          _buildSelectionCardsWidget(),
          _buildListButtonWidget(),
          _buildInventoryListWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _countedItems.isNotEmpty ? _showSummaryDialog : null,
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
