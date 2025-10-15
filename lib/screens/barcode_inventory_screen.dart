import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _isScanning = false;
  MobileScannerController? _scannerController;
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
    _requestCameraPermission();

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
    _scannerController?.dispose();
    _manualBarcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initializeScanner();
    } else {
      _showPermissionDialog();
    }
  }

  void _initializeScanner() {
    try {
      _scannerController?.dispose();
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    } catch (e) {
      print('Kamera başlatma hatası: $e');
      _showCameraErrorDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kamera İzni Gerekli'),
        content: const Text('Barkod okumak için kamera iznine ihtiyaç var.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Ayarlar'),
          ),
        ],
      ),
    );
  }

  void _loadDemoData() {
    // Demo data
    _inventoryItems = [
      InventoryItem(
        id: '1',
        barcode: '8691381000486',
        name: 'SODA',
        unit: 'Adet',
        quantity: 60,
        averagePrice: 2.50,
        totalAmount: 150.00,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '2',
        barcode: '1234567890124',
        name: 'Ekmek',
        unit: 'Adet',
        quantity: 20,
        averagePrice: 1.50,
        totalAmount: 30.00,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '3',
        barcode: '1234567890125',
        name: 'Süt 1L',
        unit: 'Adet',
        quantity: 15,
        averagePrice: 8.00,
        totalAmount: 120.00,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '4',
        barcode: '1234567890126',
        name: 'Yumurta',
        unit: 'Düzine',
        quantity: 10,
        averagePrice: 12.00,
        totalAmount: 120.00,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
      InventoryItem(
        id: '5',
        barcode: '1234567890127',
        name: 'Domates',
        unit: 'Kg',
        quantity: 25,
        averagePrice: 5.00,
        totalAmount: 125.00,
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

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
    });
    _scannerController?.stop();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String barcode = barcodes.first.rawValue ?? '';
      _processBarcode(barcode);
    }
  }

  void _processBarcode(String barcode) {
    final item = _inventoryItems.firstWhere(
      (item) => item.barcode == barcode,
      orElse: () => InventoryItem(
        id: '',
        barcode: barcode,
        name: 'Bilinmeyen Ürün',
        unit: 'Adet',
        quantity: 0,
        averagePrice: 0,
        totalAmount: 0,
        date: _selectedDate,
        department: _selectedDepartment,
      ),
    );

    if (item.id.isNotEmpty) {
      _stopScanning();
      // Miktar dialog'unu aç
      _showQuantityDialog(barcode, item.name);
    } else {
      _showUnknownBarcodeDialog(barcode);
    }
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

  void _showUnknownBarcodeDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bilinmeyen Barkod'),
        content: Text('Barkod: $barcode\nBu ürün listede bulunamadı.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(String barcode, String itemName) {
    // Default miktar 1
    _quantityController.text = '1';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Miktar Girişi - $itemName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barkod: $barcode'),
              const SizedBox(height: 16),
              // Miktar gösterimi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _quantityController.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              // Özel sayısal klavye
              _buildCustomNumericKeyboard(setDialogState),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(_quantityController.text) ?? 1;
                setState(() {
                  _countedItems[barcode] = quantity;
                  // Ürünü en üste taşı
                  _moveItemToTop(barcode);
                });
                Navigator.pop(context);
                // Odaklanmayı koru
                _barcodeFocusNode.requestFocus();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNumericKeyboard(StateSetter setDialogState) {
    return Container(
      width: 240,
      child: Column(
        children: [
          // İlk satır: 1, 2, 3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('1', setDialogState),
              _buildNumberButton('2', setDialogState),
              _buildNumberButton('3', setDialogState),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('4', setDialogState),
              _buildNumberButton('5', setDialogState),
              _buildNumberButton('6', setDialogState),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberButton('7', setDialogState),
              _buildNumberButton('8', setDialogState),
              _buildNumberButton('9', setDialogState),
            ],
          ),
          const SizedBox(height: 8),
          // Dördüncü satır: Temizle, 0, Sil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('C', () {
                _quantityController.text = '1';
                setDialogState(() {});
              }),
              _buildNumberButton('0', setDialogState),
              _buildActionButton('⌫', () {
                if (_quantityController.text.length > 1) {
                  _quantityController.text = _quantityController.text.substring(
                    0,
                    _quantityController.text.length - 1,
                  );
                } else {
                  _quantityController.text = '1';
                }
                setDialogState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number, StateSetter setDialogState) {
    return SizedBox(
      width: 60,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (_quantityController.text == '1') {
            _quantityController.text = number;
          } else {
            _quantityController.text += number;
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

  Color _getCountColor(int counted, int total) {
    if (counted == 0) {
      // Sayılmamış - soluk gri
      return Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (counted == total) {
      // Tam sayıldı - yeşil
      return Colors.green;
    } else if (counted > total) {
      // Aştı - kırmızı
      return Colors.red;
    } else {
      // Kısmen sayıldı - tema rengi
      return Theme.of(context).colorScheme.primary;
    }
  }

  void _showManualBarcodeDialog() {
    final TextEditingController dialogBarcodeController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manuel Barkod Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dialogBarcodeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Barkod',
                hintText: 'Barkod numarasını girin',
                border: OutlineInputBorder(),
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
              final barcode = dialogBarcodeController.text.trim();
              if (barcode.isNotEmpty) {
                _processBarcode(barcode);
                Navigator.pop(context);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog() {
    // Sayılmayan ürünleri bul
    final uncountedItems = _inventoryItems.where((item) {
      final countedQuantity = _countedItems[item.barcode] ?? 0;
      return countedQuantity == 0;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sayım Özeti'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Toplam ${_inventoryItems.length} ürün var'),
              Text('${_countedItems.length} ürün sayıldı'),
              Text('${uncountedItems.length} ürün sayılmadı'),
              const SizedBox(height: 16),
              if (uncountedItems.isNotEmpty) ...[
                const Text(
                  'Sayılmayan Ürünler:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...uncountedItems.map((item) {
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('Barkod: ${item.barcode}'),
                    trailing: Text('0/${item.quantity.toInt()}'),
                  );
                }),
              ] else
                const Text(
                  'Tüm ürünler sayıldı! 🎉',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
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
    if (_isScanning) return const SizedBox.shrink();

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
                        final isOverCount =
                            countedQuantity > item.quantity.toInt();
                        final isFullCount =
                            countedQuantity == item.quantity.toInt();
                        final isCompleted =
                            countedQuantity >= item.quantity.toInt();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: isCounted
                              ? (isOverCount
                                    ? Colors.red
                                    : isFullCount
                                    ? Colors.green
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer)
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCounted
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCounted
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(
                                color: isCompleted ? Colors.white : null,
                              ),
                            ),
                            subtitle: Text(
                              'Barkod: ${item.barcode}',
                              style: TextStyle(
                                color: isCompleted ? Colors.white70 : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$countedQuantity/${item.quantity.toInt()}',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.white
                                        : _getCountColor(
                                            countedQuantity,
                                            item.quantity.toInt(),
                                          ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => _showQuantityDialog(
                                    item.barcode,
                                    item.name,
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
    );
  }

  Widget _buildScannerWidget() {
    if (!_isScanning || _scannerController == null) {
      return const SizedBox.shrink();
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MobileScanner(
            controller: _scannerController!,
            onDetect: _onBarcodeDetected,
          ),
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

  Widget _buildLazerReaderWidget() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: _manualBarcodeController,
          focusNode: _barcodeFocusNode,
          keyboardType: TextInputType.none,
          textInputAction: TextInputAction.none,
          enableInteractiveSelection: false,
          showCursor: false,
          readOnly: false,
          decoration: const InputDecoration(
            hintText: 'Lazer okuyucu ile barkod okutun...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(Icons.qr_code_scanner),
          ),
          onChanged: (value) {
            // Lazer okuyucu verisi kontrolü
            print('TextField değişti: $value');

            // 8+ karakter ve Enter ile bitiyorsa işle
            if (value.length >= 8 && value.endsWith('\n')) {
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
    );
  }

  Widget _buildMainWidget() {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // Kamera butonu
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.camera_alt),
            onPressed: _isScanning ? _stopScanning : _startScanning,
            tooltip: _isScanning ? 'Kamerayı Durdur' : 'Kamera ile Tara',
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
          _buildLazerReaderWidget(),

          _buildScannerWidget(),
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

