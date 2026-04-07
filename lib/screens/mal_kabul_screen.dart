import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/department.dart';
import '../models/mal_kabul_order_item.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class MalKabulScreen extends StatefulWidget {
  const MalKabulScreen({
    super.key,
    required this.selectedDate,
    required this.girisTip,
    required this.selectedDepartment,
    this.efaturaDbId,
    this.efatSirketId,
  });

  final DateTime selectedDate;
  final String girisTip;
  final Department selectedDepartment;
  final int? efaturaDbId;
  final int? efatSirketId;

  @override
  State<MalKabulScreen> createState() => _MalKabulScreenState();
}

class _MalKabulScreenState extends State<MalKabulScreen> {
  late DateTime _selectedDate;
  late String _girisTip;
  late Department _selectedDepartment;
  int? _efaturaDbId;
  int? _efatSirketId;
  List<MalKabulOrderItem> _orderItems = [];
  bool _isLoadingOrder = false;
  bool _isSaving = false;
  final Map<String, double> _acceptedQuantities = {};
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _manualBarcodeController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode(
    debugLabel: 'BarcodeInput',
    skipTraversal: true,
  );

  Widget _infoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.95),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _selectedDate = widget.selectedDate;
    _girisTip = widget.girisTip;
    _selectedDepartment = widget.selectedDepartment;
    _efaturaDbId = widget.efaturaDbId;
    _efatSirketId = widget.efatSirketId;

    // Klavye açılmasını engelle
    _barcodeFocusNode.addListener(() {
      if (_barcodeFocusNode.hasFocus) {
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
    _orderNumberController.dispose();
    _manualBarcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    if (_orderNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen sipariş numarası girin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Sipariş getirmeden önce klavyeyi kapat.
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() {
      _isLoadingOrder = true;
    });

    try {
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();

      if (databaseProvider.selectedDatabase != null && token != null) {
        final backDbId = databaseProvider.selectedDatabase!.dbBackOfficeId ??
            databaseProvider.selectedDatabase!.id;
        final response = await ApiService.getMalKabulOrder(
          token,
          backDbId,
          _orderNumberController.text.trim(),
          true,
        );

        if (response.isSucceded) {
          setState(() {
            _orderItems = response.value;
            // Initialize accepted quantities with order quantities
            for (var item in _orderItems) {
              _acceptedQuantities[item.stokkod] = item.miktar;
            }
          });

          // Log the IDs from the fetched order
          for (var item in _orderItems) {
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${response.value.length} ürün yüklendi'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Sipariş yüklenemedi: ${response.message ?? 'Bilinmeyen hata'}',
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
            content: Text('Sipariş yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoadingOrder = false;
    });

    // Liste yüklendikten sonra barkod alanına odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barcodeFocusNode.requestFocus();
    });
  }

  Future<void> _loadByEttn() async {
    final ettn = _orderNumberController.text.trim();
    if (ettn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen ETTN girin/okutun'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_efaturaDbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departmanda efatura Db_Id bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_efatSirketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departmanda EFat_SirketID bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() => _isLoadingOrder = true);
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await ApiService.getIrsaliyeByEttnGelen(
        token: token,
        efaturaDbId: _efaturaDbId!,
        sirketId: _efatSirketId!,
        ettn: ettn,
        detay: true,
      );

      if (response.isSucceded) {
        setState(() {
          _orderItems = response.toMalKabulOrderItems();
          _acceptedQuantities.clear();
          for (final item in _orderItems) {
            _acceptedQuantities[item.stokkod] = item.miktar;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_orderItems.length} satır yüklendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response.message ?? 'İrsaliye/Fatura yüklenemedi',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
        // Liste yüklendikten sonra barkod alanına odaklan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _barcodeFocusNode.requestFocus();
        });
      }
    }
  }

  // Tarih seçimi artık seçim ekranında yapılıyor.

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

  void _showManualBarcodeDialog() {
    final TextEditingController barcodeInputController =
        TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    final FocusNode barcodeFocusNode = FocusNode();
    final FocusNode quantityFocusNode = FocusNode();
    bool isBarcodeFocused = true;

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

                    // Miktar girişi
                    TextField(
                      controller: quantityController,
                      focusNode: quantityFocusNode,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: true,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: !isBarcodeFocused ? Colors.green : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Miktar',
                        hintText: 'Miktar girin',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: !isBarcodeFocused
                                ? Colors.green
                                : Colors.grey,
                            width: 2,
                          ),
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

                    // Sayısal klavye
                    _buildNumericKeyboard(
                      barcodeInputController,
                      quantityController,
                      isBarcodeFocused,
                      setDialogState,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Builder(
                builder: (dialogContext) {
                  final actionFontSize =
                      (Theme.of(dialogContext).textTheme.labelLarge?.fontSize ??
                          14) *
                      0.75;
                  final actionTextFontSize = actionFontSize * 2;
                  final actionTextStyle = TextStyle(
                    fontSize: actionTextFontSize,
                    inherit: true,
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 9,
                            ),
                            minimumSize: const Size.fromHeight(24),
                            textStyle: actionTextStyle,
                          ),
                          icon: Icon(Icons.close, size: actionFontSize * 1.15),
                          label: const Text('İptal'),
                        ),
                        const SizedBox(height: 3),
                        ElevatedButton.icon(
                          onPressed:
                              (barcodeInputController.text.trim().isNotEmpty &&
                                  quantityController.text.trim().isNotEmpty)
                              ? () async {
                                  final barcode = barcodeInputController.text
                                      .trim();
                                  final quantity =
                                      double.tryParse(
                                        quantityController.text,
                                      ) ??
                                      1;
                                  Navigator.pop(context);
                                  _processBarcodeWithQuantity(
                                    barcode,
                                    quantity,
                                  );
                                  _barcodeFocusNode.requestFocus();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 9,
                            ),
                            minimumSize: const Size.fromHeight(24),
                            textStyle: actionTextStyle,
                          ),
                          icon: Icon(Icons.save, size: actionFontSize * 1.15),
                          label: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Sayısal klavye
  Widget _buildNumericKeyboard(
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
              _buildNumberButton(
                '1',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '2',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
                '4',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '5',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
                '7',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '8',
                barcodeController,
                quantityController,
                isBarcodeFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
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

  Widget _buildNumberButton(
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
            // Miktar girişi
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

  void _processBarcodeWithQuantity(String barcode, double quantity) {
    if (_girisTip != 'Sipariş No') {
      _orderNumberController.text = barcode;
      _loadByEttn();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ETTN: $barcode'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    // Check if barcode is a number (order number)
    final orderNumber = int.tryParse(barcode);
    if (orderNumber != null) {
      // Barcode is a number, treat it as order number
      _orderNumberController.text = barcode;
      _loadOrder();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sipariş numarası: $barcode'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // If order is not loaded yet, show message
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Önce sipariş yükleyin. Barkod: $barcode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find matching item in order
    final matchingItem = _orderItems.firstWhere(
      (item) => item.stokkod == barcode,
      orElse: () => MalKabulOrderItem(
        id: 0,
        tarih: '',
        fisno: 0,
        departman: '',
        altDepartman: '',
        stokkod: '',
        stokAd: '',
        birim: '',
        miktar: 0,
        onayMiktar: 0,
        stokMiktar: 0,
        sonalim: 0,
        tahmini: 0,
        ortalama: 0,
        tipi: '',
        seciliSatici: '',
        seciliFiyat: 0,
        seciliToplam: 0,
        saticino: 0,
        siparisno: 0,
        siparisTr: false,
        anlasmadan: false,
        depo: '',
        sonalimcari: '',
        sonalimMiktar: 0,
        barkodlandi: false,
        depStokMiktar: 0,
      ),
    );

    if (matchingItem.stokkod.isNotEmpty) {
      setState(() {
        _acceptedQuantities[matchingItem.stokkod] = quantity;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Miktar güncellendi: $quantity'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod bulunamadı: $barcode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processBarcode(String barcode) {
    if (_girisTip != 'Sipariş No') {
      _orderNumberController.text = barcode;
      _loadByEttn();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ETTN: $barcode'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    // Check if barcode is a number (order number)
    final orderNumber = int.tryParse(barcode);
    if (orderNumber != null) {
      // Barcode is a number, treat it as order number
      _orderNumberController.text = barcode;
      _loadOrder();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sipariş numarası: $barcode'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // If order is not loaded yet, show message
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Önce sipariş yükleyin. Barkod: $barcode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find matching item in order
    final matchingItem = _orderItems.firstWhere(
      (item) => item.stokkod == barcode,
      orElse: () => MalKabulOrderItem(
        id: 0,
        tarih: '',
        fisno: 0,
        departman: '',
        altDepartman: '',
        stokkod: '',
        stokAd: '',
        birim: '',
        miktar: 0,
        onayMiktar: 0,
        stokMiktar: 0,
        sonalim: 0,
        tahmini: 0,
        ortalama: 0,
        tipi: '',
        seciliSatici: '',
        seciliFiyat: 0,
        seciliToplam: 0,
        saticino: 0,
        siparisno: 0,
        siparisTr: false,
        anlasmadan: false,
        depo: '',
        sonalimcari: '',
        sonalimMiktar: 0,
        barkodlandi: false,
        depStokMiktar: 0,
      ),
    );

    if (matchingItem.stokkod.isNotEmpty) {
      _showQuantityDialog(matchingItem);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod bulunamadı: $barcode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQuantityDialog(MalKabulOrderItem item) {
    final TextEditingController quantityController = TextEditingController();
    final FocusNode quantityFocusNode = FocusNode();

    // Set initial value
    quantityController.text = (_acceptedQuantities[item.stokkod] ?? item.miktar)
        .toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentQuantity =
              _acceptedQuantities[item.stokkod] ?? item.miktar;
          final enteredQuantity = double.tryParse(quantityController.text) ?? 0;

          return AlertDialog(
            title: Text('Miktar Düzelt - ${item.stokkod}'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.5,
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

                    // Miktar girişi
                    TextField(
                      controller: quantityController,
                      focusNode: quantityFocusNode,
                      readOnly: true,
                      showCursor: true,
                      enableInteractiveSelection: true,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Miktar',
                        hintText: 'Miktar girin',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sayısal klavye
                    _buildSimpleNumericKeyboard(
                      quantityController,
                      setDialogState,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Builder(
                builder: (dialogContext) {
                  final actionFontSize =
                      (Theme.of(dialogContext).textTheme.labelLarge?.fontSize ??
                              14) *
                          0.75;
                  final actionTextFontSize = actionFontSize * 2;
                  final actionTextStyle = TextStyle(
                    fontSize: actionTextFontSize,
                    inherit: true,
                  );

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 9,
                            ),
                            minimumSize: const Size.fromHeight(24),
                            textStyle: actionTextStyle,
                          ),
                          icon: Icon(Icons.close, size: actionFontSize * 1.15),
                          label: const Text('İptal'),
                        ),
                        const SizedBox(height: 3),
                        ElevatedButton.icon(
                          onPressed: enteredQuantity > 0
                              ? () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _acceptedQuantities[item.stokkod] =
                                        enteredQuantity;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Miktar güncellendi: $enteredQuantity',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 9,
                            ),
                            minimumSize: const Size.fromHeight(24),
                            textStyle: actionTextStyle,
                          ),
                          icon: Icon(Icons.save, size: actionFontSize * 1.15),
                          label: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _editQuantity(MalKabulOrderItem item) {
    _showQuantityDialog(item);
  }

  // Basit sayısal klavye
  Widget _buildSimpleNumericKeyboard(
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
              _buildSimpleNumberButton('1', quantityController, setDialogState),
              _buildSimpleNumberButton('2', quantityController, setDialogState),
              _buildSimpleNumberButton('3', quantityController, setDialogState),
            ],
          ),
          const SizedBox(height: 8),
          // İkinci satır: 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleNumberButton('4', quantityController, setDialogState),
              _buildSimpleNumberButton('5', quantityController, setDialogState),
              _buildSimpleNumberButton('6', quantityController, setDialogState),
            ],
          ),
          const SizedBox(height: 8),
          // Üçüncü satır: 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleNumberButton('7', quantityController, setDialogState),
              _buildSimpleNumberButton('8', quantityController, setDialogState),
              _buildSimpleNumberButton('9', quantityController, setDialogState),
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
              _buildSimpleNumberButton('0', quantityController, setDialogState),
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

  Widget _buildSimpleNumberButton(
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

  Future<void> _saveMalKabul() async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce sipariş yükleyin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();

      if (databaseProvider.selectedDatabase != null && token != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        final refNo = _orderNumberController.text
            .trim(); // Use order number as RefNo

        final satirlar = <Map<String, dynamic>>[];

        for (var item in _orderItems) {
          final acceptedQuantity =
              _acceptedQuantities[item.stokkod] ?? item.miktar;


          satirlar.add({
            'Id': 0, // ID from the fetched order
            'EfatId': item.id, // Use the same ID
            'Sira': 0,
            'UrunAdi': 'Ürün ${item.stokkod}',
            'Firma': 'Tedarikçi',
            'Miktar': acceptedQuantity,
            'Birim': item.birim,
            'PartiNo': '${item.id}-${DateTime.now().millisecondsSinceEpoch}',
            'SonKullanimTarih': DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now().add(const Duration(days: 365))),
            'UrunSicaklik': 24.5,
            'AracSicaklik': 22.5,
            'UrunOnay': true,
            'AracOnay': true,
            'PandemiOnay': true,
            'HammaddeOnay': true,
            'DezenfeksiyonOnay': true,
            'PersonelOnay': true,
          });
        }

        final requestBody = {
          'db_Id': databaseProvider.selectedDatabase!.id,
          'Tarih': dateStr,
          'RefTip': 'S',
          'RefNo': refNo,
          'Efat_Sirket': 1,
          'Efat_Db': '10001_Rmos_E',
          'Satirlar': satirlar,
        };

        // Log request details

        // Log complete JSON request body
        const encoder = JsonEncoder.withIndent('  ');
        final jsonString = encoder.convert(requestBody);
        developer.log(jsonString, name: 'MAL_KABUL_REQUEST_JSON');

        // Log EfatId values being sent
        for (var satir in satirlar) {
        }

        final response = await ApiService.saveMalKabul(
          token,
          databaseProvider.selectedDatabase!.id,
          dateStr,
          'S',
          refNo,
          1,
          '10001_Rmos_E',
          satirlar,
        );

        // Log response details
        developer.log(
          'isSucceded: ${response['isSucceded']}',
          name: 'MAL_KABUL_RESPONSE',
        );
        developer.log(
          'message: ${response['message']}',
          name: 'MAL_KABUL_RESPONSE',
        );
        developer.log(
          'messageList: ${response['messageList']}',
          name: 'MAL_KABUL_RESPONSE',
        );
        developer.log(
          'value: ${response['value']}',
          name: 'MAL_KABUL_RESPONSE',
        );

        if (response['isSucceded'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Mal Kabul kaydedildi'),
                backgroundColor: Colors.green,
              ),
            );
            // Clear the form
            setState(() {
              _orderItems.clear();
              _acceptedQuantities.clear();
              _orderNumberController.clear();
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Bilinmeyen hata'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 28,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        titleSpacing: 8,
        title: Card(
          margin: const EdgeInsets.only(right: 4),
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
            showCursor: true,
            readOnly: false,
            decoration: const InputDecoration(
              hintText: 'Barkod okutun...',
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
        actions: [
          // Kamera ile barkod okuma butonu
          Card(
            margin: const EdgeInsets.only(left: 5, right: 5),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              iconSize: 48,
              onPressed: _scanBarcode,
              tooltip: 'Kamera ile Tara',
            ),
          ),
          // Manuel barkod ekleme butonu
          Card(
            margin: const EdgeInsets.only(left: 5, right: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(Icons.add),
              iconSize: 48,
              onPressed: _showManualBarcodeDialog,
              tooltip: 'Manuel Barkod Ekle',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tarih: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}  •  Dep: ${_selectedDepartment.kod}  •  Giriş: $_girisTip',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Order number input
                LayoutBuilder(
                  builder: (context, constraints) {
                    final baseFs =
                        (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                            14);
                    final scaledFontSize =
                        (constraints.maxWidth < 520 ? baseFs * 1.25 : baseFs * 1.5);

                    final orderField = TextField(
                      controller: _orderNumberController,
                      style: TextStyle(fontSize: scaledFontSize),
                      decoration: InputDecoration(
                        labelText: _girisTip == 'Sipariş No' ? 'Sipariş No' : 'ETTN',
                        labelStyle: TextStyle(fontSize: scaledFontSize),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.receipt_long, size: 40),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _orderNumberController.clear();
                            setState(() {});
                          },
                          tooltip: 'Temizle',
                        ),
                      ),
                      keyboardType: _girisTip == 'Sipariş No'
                          ? TextInputType.number
                          : TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!_isLoadingOrder) {
                          if (_girisTip == 'Sipariş No') {
                            _loadOrder();
                          } else {
                            _loadByEttn();
                          }
                        }
                      },
                    );

                    final orderButton = ElevatedButton.icon(
                      onPressed: _isLoadingOrder
                          ? null
                          : (_girisTip == 'Sipariş No' ? _loadOrder : _loadByEttn),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        minimumSize: const Size(0, 56),
                        textStyle: TextStyle(
                          fontSize: scaledFontSize,
                          inherit: true,
                        ),
                      ),
                      icon: _isLoadingOrder
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(Icons.list, size: scaledFontSize * 1.2),
                      label: const Text('LİSTELE'),
                    );

                    return Row(
                      children: [
                        Expanded(child: orderField),
                        const SizedBox(width: 8),
                        SizedBox(
                          width:
                              constraints.maxWidth < 520
                                  ? (constraints.maxWidth * 0.35)
                                  : null,
                          child: orderButton,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          // Order items list
          Expanded(
            child: _orderItems.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // Klavye açılınca yükseklik daralıyor; scroll vererek overflow'u önle.
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sipariş yüklemek için sipariş numarası girin',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                    itemCount: _orderItems.length,
                    itemBuilder: (context, index) {
                      final item = _orderItems[index];
                      final acceptedQuantity =
                          _acceptedQuantities[item.stokkod] ?? item.miktar;

                      final orderQtyStr = item.miktar.toStringAsFixed(0);
                      final acceptedQtyStr =
                          acceptedQuantity.toStringAsFixed(0);
                      final priceStr = item.seciliFiyat.toStringAsFixed(2);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.stokAd.isEmpty
                                              ? '(StokAd yok)'
                                              : item.stokAd,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.stokkod,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '#${item.id}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Card(
                                    elevation: 2,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _editQuantity(item),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Düzenle',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _infoChip(
                                    label: 'Sipariş',
                                    value: '$orderQtyStr ${item.birim}',
                                    color: Colors.blue,
                                  ),
                                  _infoChip(
                                    label: 'Kabul',
                                    value: '$acceptedQtyStr ${item.birim}',
                                    color: Colors.green,
                                  ),
                                  _infoChip(
                                    label: 'Fiyat',
                                    value: '$priceStr TL',
                                    color: Colors.orange,
                                  ),
                                ],
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
      floatingActionButton: _orderItems.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _saveMalKabul,
              label: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gönder'),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
            )
          : null,
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
