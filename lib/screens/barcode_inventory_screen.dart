import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/inventory_item.dart';

class BarcodeInventoryScreen extends StatefulWidget {
  const BarcodeInventoryScreen({super.key});

  @override
  State<BarcodeInventoryScreen> createState() => _BarcodeInventoryScreenState();
}

class _BarcodeInventoryScreenState extends State<BarcodeInventoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedDepartment = 'Ana Depo';
  String _selectedType = 'stok'; // 'stok' or 'reçete'
  List<InventoryItem> _inventoryItems = [];
  bool _isLoading = false;
  final Map<String, int> _countedItems = {};
  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(
    debugLabel: 'BarcodeInput',
    skipTraversal: true,
  );

  final List<String> _departments = ['Ana Depo', 'Yemek Sepeti'];

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
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _loadDemoData() {
    // Demo data - sadece barkod örnekleri
    _inventoryItems = [
      InventoryItem(
        id: '1',
        barcode: '1213123',
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '2',
        barcode: '1213123',
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '3',
        barcode: '1213123',
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '4',
        barcode: '1213123',
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '5',
        barcode: '1213123',
        name: '',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
    ];
  }

  void _selectDate() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 216,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
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
      ),
    );
  }

  void _selectDepartment() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Departman Seçin',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._departments.map(
              (dept) => ListTile(
                title: Text(dept),
                leading: Radio<String>(
                  value: dept,
                  groupValue: _selectedDepartment,
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTypeSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tür Seçin', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            RadioListTile<String>(
              title: const Text('Stok'),
              value: 'stok',
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Reçete'),
              value: 'reçete',
              groupValue: _selectedType,
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _loadInventory() {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
        _loadDemoData();
      });
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
        department: _selectedDepartment,
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
    final FocusNode addQuantityFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final addQuantity = int.tryParse(addQuantityController.text) ?? 0;
          final newTotal = currentQuantity + addQuantity;

          return AlertDialog(
            title: Text('Miktar Ekle - Barkod: $barcode'),
            content: Column(
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
                // Eklenecek miktar
                TextField(
                  controller: addQuantityController,
                  focusNode: addQuantityFocusNode,
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Eklenecek Miktar',
                    hintText: 'Miktar girin',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Yeni toplam
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Yeni Toplam: $newTotal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Özel sayısal klavye - Sadece miktar girişi
                _buildProductQuantityKeyboard(
                  addQuantityController,
                  setDialogState,
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
                  final addQuantity =
                      int.tryParse(addQuantityController.text) ?? 0;
                  if (addQuantity > 0) {
                    setState(() {
                      _countedItems[barcode] = currentQuantity + addQuantity;
                      // Ürünü en üste taşı
                      _moveItemToTop(barcode);
                    });
                    Navigator.pop(context);
                    // Odaklanmayı koru
                    _barcodeFocusNode.requestFocus();
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnifiedKeyboard(
    TextEditingController barcodeController,
    TextEditingController quantityController,
    bool isBarcodeFocused,
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
              _buildUnifiedNumberButton(
                '1',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '2',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '3',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUnifiedNumberButton(
                '4',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '5',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '6',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUnifiedNumberButton(
                '7',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '8',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildUnifiedNumberButton(
                '9',
                barcodeController,
                quantityController,
                isBarcodeFocused,
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
                } else {
                  quantityController.text = '';
                  quantityController.selection = TextSelection.fromPosition(
                    TextPosition(offset: quantityController.text.length),
                  );
                }
                setDialogState(() {});
              }),
              _buildUnifiedNumberButton(
                '0',
                barcodeController,
                quantityController,
                isBarcodeFocused,
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
                } else {
                  if (quantityController.text.isNotEmpty) {
                    quantityController.text = quantityController.text.substring(
                      0,
                      quantityController.text.length - 1,
                    );
                  }
                  quantityController.selection = TextSelection.fromPosition(
                    TextPosition(offset: quantityController.text.length),
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

  Widget _buildUnifiedNumberButton(
    String number,
    TextEditingController barcodeController,
    TextEditingController quantityController,
    bool isBarcodeFocused,
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
          } else {
            // Miktar girişi - direkt ekleme
            quantityController.text += number;
            quantityController.selection = TextSelection.fromPosition(
              TextPosition(offset: quantityController.text.length),
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

  Widget _buildProductQuantityKeyboard(
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
              _buildProductNumberButton(
                '1',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
                '2',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
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
              _buildProductNumberButton(
                '4',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
                '5',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
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
              _buildProductNumberButton(
                '7',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
                '8',
                quantityController,
                setDialogState,
              ),
              _buildProductNumberButton(
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
              _buildActionButton('C', () {
                quantityController.text = '';
                quantityController.selection = TextSelection.fromPosition(
                  TextPosition(offset: quantityController.text.length),
                );
                setDialogState(() {});
              }),
              _buildProductNumberButton(
                '0',
                quantityController,
                setDialogState,
              ),
              _buildActionButton('⌫', () {
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

  Widget _buildProductNumberButton(
    String number,
    TextEditingController quantityController,
    StateSetter setDialogState,
  ) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          // Miktar girişi - direkt ekleme
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

  Widget _buildDuzeltButton(String barcode, String itemName) {
    return SizedBox(
      width: 120,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: () => _showProductQuantityDialog(barcode, itemName),
        icon: Icon(Icons.add, size: 20),
        label: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text('Düzelt'),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSilButton(String barcode, String itemName, bool isCounted) {
    return SizedBox(
      width: 120,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: isCounted
            ? () => _showDeleteConfirmationDialog(barcode, itemName)
            : null,
        icon: Icon(Icons.delete, size: 20),
        label: Text('Sil'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCounted
              ? Colors.red.shade700
              : Colors.grey.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  void _showManualBarcodeDialog() {
    final TextEditingController barcodeInputController =
        TextEditingController();
    final TextEditingController quantityInputController = TextEditingController(
      text: '1',
    );
    final FocusNode barcodeFocusNode = FocusNode();
    final FocusNode quantityFocusNode = FocusNode();
    bool isBarcodeFocused = true;

    // Miktar alanındaki metni seç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      quantityInputController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: quantityInputController.text.length,
      );
    });

    // Başlangıçta barkod alanına odaklan
    barcodeFocusNode.addListener(() {
      if (barcodeFocusNode.hasFocus) {
        isBarcodeFocused = true;
      }
    });

    quantityFocusNode.addListener(() {
      if (quantityFocusNode.hasFocus) {
        isBarcodeFocused = false;
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentQuantity =
              _countedItems[barcodeInputController.text.trim()] ?? 0;
          final addQuantity = int.tryParse(quantityInputController.text) ?? 0;
          final newTotal = currentQuantity + addQuantity;

          return AlertDialog(
            title: const Text('Manuel Barkod Ekle'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barkod girişi
                TextField(
                  controller: barcodeInputController,
                  focusNode: barcodeFocusNode,
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final clipboardData = await Clipboard.getData(
                          'text/plain',
                        );
                        if (clipboardData?.text != null) {
                          barcodeInputController.text = clipboardData!.text!;
                          barcodeInputController.selection =
                              TextSelection.fromPosition(
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
                // Miktar girişi
                TextField(
                  controller: quantityInputController,
                  focusNode: quantityFocusNode,
                  readOnly: true,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Eklenecek Miktar',
                    hintText: 'Miktar girin',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onTap: () {
                    setDialogState(() {
                      isBarcodeFocused = false;
                      quantityFocusNode.requestFocus();
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Mevcut miktar ve yeni toplam
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
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Yeni Toplam: $newTotal',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Özel sayısal klavye
                _buildUnifiedKeyboard(
                  barcodeInputController,
                  quantityInputController,
                  isBarcodeFocused,
                  setDialogState,
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
                  final barcode = barcodeInputController.text.trim();
                  final quantityText = quantityInputController.text.trim();
                  final quantity = quantityText.isEmpty
                      ? 1
                      : int.tryParse(quantityText) ?? 1;

                  if (barcode.isNotEmpty) {
                    // Barkod var mı kontrol et
                    final existingItemIndex = _inventoryItems.indexWhere(
                      (item) => item.barcode == barcode,
                    );

                    if (existingItemIndex != -1) {
                      // Mevcut ürün - miktarını güncelle
                      setState(() {
                        _countedItems[barcode] =
                            (_countedItems[barcode] ?? 0) + quantity;
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
                        department: _selectedDepartment,
                      );

                      setState(() {
                        _inventoryItems.insert(0, newItem);
                        _countedItems[barcode] = quantity;
                      });
                    }

                    Navigator.pop(context);
                    // Odaklanmayı koru
                    _barcodeFocusNode.requestFocus();
                  }
                },
                child: const Text('Kaydet'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog() {
    // Toplam sayılan miktarı hesapla
    final totalCounted = _countedItems.values.fold(
      0,
      (sum, count) => sum + count,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sayım Özeti'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Toplam ${_inventoryItems.length} farklı barkod'),
              Text('Toplam ${totalCounted} adet sayıldı'),
              const SizedBox(height: 16),
              const Text(
                'Sayılan Barkodlar:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._countedItems.entries.map((entry) {
                return ListTile(
                  title: Text('Barkod: ${entry.key}'),
                  trailing: Text('${entry.value} adet'),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
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
              child: _inventoryItems.isEmpty
                  ? Center(
                      child: Text(
                        'Listele butonuna basarak ürünleri yükleyin',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 150),
                      itemCount: _inventoryItems.length,
                      itemBuilder: (context, index) {
                        final item = _inventoryItems[index];
                        final countedQuantity =
                            _countedItems[item.barcode] ?? 0;
                        final isCounted = countedQuantity > 0;

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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Text(
                                          item.name.isEmpty
                                              ? 'Barkod: ${item.barcode}'
                                              : item.name,
                                          style: TextStyle(
                                            color: isCounted
                                                ? Colors.green
                                                : null,
                                            fontWeight: isCounted
                                                ? FontWeight.bold
                                                : null,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (item.name.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Barkod: ${item.barcode}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        // Sayılan adet göstergesi
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isCounted
                                                ? Colors.green.shade100
                                                : Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: isCounted
                                                  ? Colors.green.shade300
                                                  : Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Sayılan: $countedQuantity',
                                            style: TextStyle(
                                              color: isCounted
                                                  ? Colors.green.shade800
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),

                                  // Buttons - Column with fixed width, right aligned
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Sil button
                                      _buildSilButton(
                                        item.barcode,
                                        item.name,
                                        isCounted,
                                      ),
                                      const SizedBox(height: 6),
                                      // Düzelt button
                                      _buildDuzeltButton(
                                        item.barcode,
                                        item.name,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Divider between items
                            if (index < _inventoryItems.length - 1)
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
          onPressed: _isLoading ? null : _loadInventory,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
          label: Text(
            _isLoading ? 'Yükleniyor...' : 'Listele',
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Tarih Seçiniz',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              child: InkWell(
                onTap: _selectDepartment,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Departman Seçiniz',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      const Icon(Icons.business, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        _selectedDepartment,
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
          // Type Selection
          Expanded(
            child: Card(
              child: InkWell(
                onTap: _showTypeSelection,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Tip Seçiniz',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        _selectedType == 'stok'
                            ? Icons.inventory
                            : Icons.receipt,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedType == 'stok' ? 'Stok' : 'Reçete',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
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
        actions: [
          // Lazer okuyucu TextField
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(right: 5, left: 15),
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
