import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/product.dart';
import '../models/request_item.dart';

class AmberRequestScreen extends StatefulWidget {
  const AmberRequestScreen({super.key});

  @override
  State<AmberRequestScreen> createState() => _AmberRequestScreenState();
}

class _AmberRequestScreenState extends State<AmberRequestScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedDepartment = 'Ana Depo';
  List<Product> _products = [];
  final List<RequestItem> _requestItems = [];
  final Map<String, int> _requestedItems = {};
  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(
    debugLabel: 'BarcodeInput',
    skipTraversal: true,
  );

  final List<String> _departments = ['Ana Depo', 'Yerel Depo'];

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
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _loadDemoProducts() {
    // Demo data - 20 ürün
    _products = [
      Product(
        stokad: 'Soda',
        stokkod: '8691381000486',
        kalanmiktar: 50,
        fiyat: 100.00,
      ),
      Product(
        stokad: 'Ekmek',
        stokkod: '8697950727044',
        kalanmiktar: 25,
        fiyat: 3.00,
      ),
      Product(
        stokad: 'Yumurta 30lu',
        stokkod: 'ST003',
        kalanmiktar: 15,
        fiyat: 45.00,
      ),
      Product(
        stokad: 'Peynir 500g',
        stokkod: 'ST004',
        kalanmiktar: 30,
        fiyat: 25.00,
      ),
      Product(
        stokad: 'Tereyağı 250g',
        stokkod: 'ST005',
        kalanmiktar: 20,
        fiyat: 35.00,
      ),
      Product(
        stokad: 'Zeytin 1kg',
        stokkod: 'ST006',
        kalanmiktar: 40,
        fiyat: 18.00,
      ),
      Product(
        stokad: 'Domates 1kg',
        stokkod: 'ST007',
        kalanmiktar: 60,
        fiyat: 12.00,
      ),
      Product(
        stokad: 'Salatalık 1kg',
        stokkod: 'ST008',
        kalanmiktar: 35,
        fiyat: 8.00,
      ),
      Product(
        stokad: 'Soğan 1kg',
        stokkod: 'ST009',
        kalanmiktar: 80,
        fiyat: 6.00,
      ),
      Product(
        stokad: 'Patates 1kg',
        stokkod: 'ST010',
        kalanmiktar: 100,
        fiyat: 4.50,
      ),
      Product(
        stokad: 'Havuç 1kg',
        stokkod: 'ST011',
        kalanmiktar: 45,
        fiyat: 7.00,
      ),
      Product(
        stokad: 'Elma 1kg',
        stokkod: 'ST012',
        kalanmiktar: 55,
        fiyat: 9.00,
      ),
      Product(
        stokad: 'Muz 1kg',
        stokkod: 'ST013',
        kalanmiktar: 30,
        fiyat: 15.00,
      ),
      Product(
        stokad: 'Portakal 1kg',
        stokkod: 'ST014',
        kalanmiktar: 40,
        fiyat: 11.00,
      ),
      Product(
        stokad: 'Limon 1kg',
        stokkod: 'ST015',
        kalanmiktar: 25,
        fiyat: 8.50,
      ),
      Product(
        stokad: 'Çay 500g',
        stokkod: 'ST016',
        kalanmiktar: 20,
        fiyat: 22.00,
      ),
      Product(
        stokad: 'Kahve 250g',
        stokkod: 'ST017',
        kalanmiktar: 15,
        fiyat: 45.00,
      ),
      Product(
        stokad: 'Şeker 1kg',
        stokkod: 'ST018',
        kalanmiktar: 50,
        fiyat: 6.50,
      ),
      Product(
        stokad: 'Tuz 1kg',
        stokkod: 'ST019',
        kalanmiktar: 30,
        fiyat: 2.50,
      ),
      Product(stokad: 'Un 1kg', stokkod: 'ST020', kalanmiktar: 25, fiyat: 8.00),
    ];
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
              (dept) => Card(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDepartment = dept;
                    });
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListTile(
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
                      title: Text(
                        dept,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductSelectionDialog() {
    _loadDemoProducts(); // Load products for the dialog
    final TextEditingController searchController = TextEditingController();
    List<Product> filteredProducts = _products;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter products based on search text
          if (searchController.text.isNotEmpty) {
            filteredProducts = _products.where((product) {
              final searchText = searchController.text.toLowerCase();
              return product.stokad.toLowerCase().contains(searchText) ||
                  product.stokkod.toLowerCase().contains(searchText);
            }).toList();
          } else {
            filteredProducts = _products;
          }

          return AlertDialog(
            title: const Text('Ürün Seçin'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: Column(
                children: [
                  // Search TextField
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Ürün adı veya stok kodu ara...',
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
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  // Products List
                  Expanded(
                    child: _products.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : filteredProducts.isEmpty
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
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
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
                                    product.stokad,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Stok Kodu: ${product.stokkod}'),
                                      Text(
                                        'Mevcut: ${product.kalanmiktar} adet',
                                      ),
                                      Text(
                                        'Fiyat: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(product.fiyat)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showProductQuantityDialog(product);
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
    // Barkod ile ürün ara
    final product = _products.firstWhere(
      (p) => p.stokkod == barcode,
      orElse: () => Product(stokad: '', stokkod: '', kalanmiktar: 0, fiyat: 0),
    );

    if (product.stokkod.isNotEmpty) {
      // Barkod okutulduğunda direkt 1 tane ekle
      _addProductToRequest(product, 1);
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

  void _addProductToRequest(Product product, int quantity) {
    final existingItemIndex = _requestItems.indexWhere(
      (item) => item.stokkod == product.stokkod,
    );

    if (existingItemIndex != -1) {
      // Mevcut ürün - miktarını güncelle
      setState(() {
        _requestedItems[product.stokkod] = quantity;
        _requestItems[existingItemIndex] = _requestItems[existingItemIndex]
            .copyWith(
              talepedilenMiktar: quantity,
              toplamTutar: quantity * product.fiyat,
            );
        // Ürünü en üste taşı
        _moveItemToTop(product.stokkod);
      });
    } else {
      // Yeni ürün - listeye ekle
      final newItem = RequestItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        stokad: product.stokad,
        stokkod: product.stokkod,
        kalanmiktar: product.kalanmiktar,
        fiyat: product.fiyat,
        talepedilenMiktar: quantity,
        toplamTutar: quantity * product.fiyat,
        date: _selectedDate,
        department: _selectedDepartment,
      );

      setState(() {
        _requestItems.insert(0, newItem);
        _requestedItems[product.stokkod] = quantity;
      });
    }

    // Odaklanmayı koru
    _barcodeFocusNode.requestFocus();
  }

  void _moveItemToTop(String stokkod) {
    // Stokkod ile eşleşen ürünü bul ve en üste taşı
    final itemIndex = _requestItems.indexWhere(
      (item) => item.stokkod == stokkod,
    );
    if (itemIndex != -1) {
      final item = _requestItems.removeAt(itemIndex);
      _requestItems.insert(0, item);
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
          final totalAmount = finalQuantity * product.fiyat;

          return AlertDialog(
            title: Text('Miktar Gir - ${product.stokad}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ürün bilgileri
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            product.stokad,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stok Kodu: ${product.stokkod}',
                            style: const TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mevcut Miktar: ${product.kalanmiktar}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fiyat: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(product.fiyat)}',
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

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
                                  Icon(
                                    isCurrentRequestExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mevcut Talep: $currentQuantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                          const SizedBox(height: 4),
                          Text(
                            'Toplam Tutar: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: isValidQuantity
                    ? () {
                        _addProductToRequest(product, finalQuantity);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Kaydet'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _requestedItems.remove(stokkod);
                _requestItems.removeWhere((item) => item.stokkod == stokkod);
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
    // Toplam talep edilen miktarı hesapla
    final totalRequested = _requestedItems.values.fold(
      0,
      (sum, count) => sum + count,
    );

    // Toplam tutarı hesapla
    final totalAmount = _requestItems.fold(
      0.0,
      (sum, item) => sum + item.toplamTutar,
    );

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
                // Özet kartları
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Ürün Sayısı',
                        '${_requestItems.length}',
                        Icons.inventory_2,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Toplam Adet',
                        '$totalRequested',
                        Icons.shopping_cart,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toplam tutar kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toplam Tutar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(
                          locale: 'tr_TR',
                          symbol: '₺',
                        ).format(totalAmount),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Ürün listesi başlığı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.grey, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Talep Edilen Ürünler',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Ürün listesi
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _requestedItems.entries.length,
                    itemBuilder: (context, index) {
                      final entry = _requestedItems.entries.elementAt(index);
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
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Kapat', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Tamam',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
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
          label: const Text('Ürünleri Listele', style: TextStyle(fontSize: 16)),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
            tooltip: 'Ürünleri Listele',
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
