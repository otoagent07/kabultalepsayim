import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/department.dart';
import '../models/sayim_item.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/alice_inspector_button.dart';

class BarcodeInventoryScreen extends StatefulWidget {
  const BarcodeInventoryScreen({
    super.key,
    required this.selectedDate,
    required this.selectedDepartment,
  });

  final DateTime selectedDate;
  final Department selectedDepartment;

  @override
  State<BarcodeInventoryScreen> createState() => _BarcodeInventoryScreenState();
}

class _BarcodeInventoryScreenState extends State<BarcodeInventoryScreen> {
  late DateTime _selectedDate;
  late Department _selectedDepartment;
  List<SayimItem> _sayimItems = [];
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
    _selectedDate = widget.selectedDate;
    _selectedDepartment = widget.selectedDepartment;

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
      _loadInventory();
    });
  }

  @override
  void dispose() {
    _manualBarcodeController.dispose();
    _quantityController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  // Departman seçimi artık seçim ekranında yapılıyor.

  // Tarih seçimi artık seçim ekranında yapılıyor.

  Future<void> _loadInventory() async {
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
          _selectedDepartment.kod,
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

    // Liste yüklendikten sonra barkod alanına odaklan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barcodeFocusNode.requestFocus();
    });
  }

  Future<void> _processBarcode(String barcode) async {

    try {
      final token = await StorageService.getToken();
      final selectedDatabase = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      ).selectedDatabase;

      if (token == null || selectedDatabase == null) {
        _showErrorSnackBar('Token veya veritabanı bilgisi bulunamadı');
        return;
      }

      // Tarih hesaplaması - tarih1: ayın ilk günü, tarih2: seçilen tarih
      final tarih2 = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final tarih1 = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_selectedDate.year, _selectedDate.month, 1));

      // Barkod kontrolü yap
      final barkodResponse = await ApiService.checkBarkod(
        token,
        selectedDatabase.id,
        tarih1,
        tarih2,
        barcode,
      );

      if (barkodResponse.isSucceded) {
        if (barkodResponse.value.isNotEmpty) {
          final barkodItem = barkodResponse.value.first;

          // Ürün listesinde var mı kontrol et (Master_GenelKod ile)
          final existingItemIndex = _sayimItems.indexWhere(
            (item) => item.sayimStokkod == barkodItem.masterGenelKod,
          );

          if (existingItemIndex != -1) {
            // Ürün zaten listede, miktarı 1 artır ve API'ye kaydet
            final updatedQuantity =
                _sayimItems[existingItemIndex].sayimMiktar + 1;

            final success = await ApiService.saveSayimItem(
              token,
              selectedDatabase.id,
              _sayimItems[existingItemIndex].sayimId,
              DateFormat('yyyy-MM-dd').format(_selectedDate),
              _selectedDepartment.kod,
              barkodItem.masterGenelKod,
              barkodItem.barkod,
              barkodItem.masterAltbirim,
              updatedQuantity.toInt(),
            );

            if (success) {
              setState(() {
                _sayimItems[existingItemIndex] = SayimItem(
                  sayimId: _sayimItems[existingItemIndex].sayimId,
                  sayimTarih: _sayimItems[existingItemIndex].sayimTarih,
                  sayimDepartman: _sayimItems[existingItemIndex].sayimDepartman,
                  sayimStokkod: _sayimItems[existingItemIndex].sayimStokkod,
                  sayimBarkod: _sayimItems[existingItemIndex].sayimBarkod,
                  sayimAltbirim: _sayimItems[existingItemIndex].sayimAltbirim,
                  sayimMiktar: updatedQuantity,
                  sayimTipi: _sayimItems[existingItemIndex].sayimTipi,
                  depAd: _sayimItems[existingItemIndex].depAd,
                  masterAd: _sayimItems[existingItemIndex].masterAd,
                  sayimOrtalama: _sayimItems[existingItemIndex].sayimOrtalama,
                  sayimTutar: _sayimItems[existingItemIndex].sayimTutar,
                );
              });

              _showSuccessSnackBar('${barkodItem.masterAd} miktarı artırıldı');
            } else {
              _showErrorSnackBar('Miktar artırma başarısız');
            }
          } else {
            // Yeni ürün ekle ve API'ye kaydet
            final success = await ApiService.saveSayimItem(
              token,
              selectedDatabase.id,
              0, // Yeni ürün için 0
              DateFormat('yyyy-MM-dd').format(_selectedDate),
              _selectedDepartment.kod,
              barkodItem.masterGenelKod,
              barkodItem.barkod,
              barkodItem.masterAltbirim,
              1,
            );

            if (success) {
              final newItem = SayimItem(
                sayimId: 0, // Yeni ürün için 0
                sayimTarih: DateFormat('yyyy-MM-dd').format(_selectedDate),
                sayimDepartman: _selectedDepartment.kod,
                sayimStokkod: barkodItem.masterGenelKod,
                sayimBarkod: barkodItem.barkod,
                sayimAltbirim: barkodItem.masterAltbirim,
                sayimMiktar: 1,
                sayimTipi: 'S',
                depAd: _selectedDepartment.ad,
                masterAd: barkodItem.masterAd,
                sayimOrtalama: 0,
                sayimTutar: 0,
              );

              setState(() {
                _sayimItems.add(newItem);
              });

              _showSuccessSnackBar('${barkodItem.masterAd} eklendi');
            } else {
              _showErrorSnackBar('Ürün ekleme başarısız');
            }
          }
        } else {
          // Value boş - barkod yoktur
          _showErrorSnackBar('Barkod yoktur: $barcode');
        }
      } else {
        _showErrorSnackBar('Barkod kontrolü başarısız: $barcode');
      }
    } catch (e) {
      _showErrorSnackBar('Barkod kontrolü hatası: $e');
    }

    // Odaklanmayı koru
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _processManualBarcode(String barcode, int quantity) async {

    try {
      // Önce mevcut listede barkod ile eşleşen ürün var mı kontrol et
      final existingItemByBarcode = _sayimItems.firstWhere(
        (item) => item.sayimBarkod == barcode,
        orElse: () => SayimItem(
          sayimId: -1,
          sayimTarih: '',
          sayimDepartman: '',
          sayimStokkod: '',
          sayimBarkod: '',
          sayimAltbirim: '',
          sayimMiktar: 0,
          sayimTipi: '',
          depAd: '',
          masterAd: '',
          sayimOrtalama: 0,
          sayimTutar: 0,
        ),
      );

      // Listede barkod bulundu
      if (existingItemByBarcode.sayimId != -1) {
        final token = await StorageService.getToken();
        final selectedDatabase = Provider.of<SelectedDatabaseProvider>(
          context,
          listen: false,
        ).selectedDatabase;

        if (token == null || selectedDatabase == null) {
          _showErrorSnackBar('Token veya veritabanı bilgisi bulunamadı');
          return;
        }

        // Miktarı güncelle ve API'ye kaydet
        final success = await ApiService.saveSayimItem(
          token,
          selectedDatabase.id,
          existingItemByBarcode.sayimId,
          DateFormat('yyyy-MM-dd').format(_selectedDate),
          _selectedDepartment.kod,
          existingItemByBarcode.sayimStokkod,
          existingItemByBarcode.sayimBarkod,
          existingItemByBarcode.sayimAltbirim,
          quantity,
        );

        if (success) {
          final existingItemIndex = _sayimItems.indexWhere(
            (item) => item.sayimId == existingItemByBarcode.sayimId,
          );

          setState(() {
            _sayimItems[existingItemIndex] = SayimItem(
              sayimId: existingItemByBarcode.sayimId,
              sayimTarih: existingItemByBarcode.sayimTarih,
              sayimDepartman: existingItemByBarcode.sayimDepartman,
              sayimStokkod: existingItemByBarcode.sayimStokkod,
              sayimBarkod: existingItemByBarcode.sayimBarkod,
              sayimAltbirim: existingItemByBarcode.sayimAltbirim,
              sayimMiktar: quantity.toDouble(),
              sayimTipi: existingItemByBarcode.sayimTipi,
              depAd: existingItemByBarcode.depAd,
              masterAd: existingItemByBarcode.masterAd,
              sayimOrtalama: existingItemByBarcode.sayimOrtalama,
              sayimTutar: existingItemByBarcode.sayimTutar,
            );
          });

          _showSuccessSnackBar(
            '${existingItemByBarcode.masterAd} miktarı güncellendi: $quantity',
          );
        } else {
          _showErrorSnackBar('Miktar güncelleme başarısız');
        }
        return;
      }

      // Listede yoksa API'den sorgula
      final token = await StorageService.getToken();
      final selectedDatabase = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      ).selectedDatabase;

      if (token == null || selectedDatabase == null) {
        _showErrorSnackBar('Token veya veritabanı bilgisi bulunamadı');
        return;
      }

      // Tarih hesaplaması - tarih1: ayın ilk günü, tarih2: seçilen tarih
      final tarih2 = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final tarih1 = DateFormat(
        'yyyy-MM-dd',
      ).format(DateTime(_selectedDate.year, _selectedDate.month, 1));

      // Barkod kontrolü yap
      final barkodResponse = await ApiService.checkBarkod(
        token,
        selectedDatabase.id,
        tarih1,
        tarih2,
        barcode,
      );

      if (barkodResponse.isSucceded) {
        if (barkodResponse.value.isNotEmpty) {
          final barkodItem = barkodResponse.value.first;

          // Ürün listesinde stok kodu ile var mı kontrol et (Master_GenelKod ile)
          final existingItemIndex = _sayimItems.indexWhere(
            (item) => item.sayimStokkod == barkodItem.masterGenelKod,
          );

          if (existingItemIndex != -1) {
            // Ürün listede var (farklı barkod ile), miktarı güncelle ve API'ye kaydet
            final success = await ApiService.saveSayimItem(
              token,
              selectedDatabase.id,
              _sayimItems[existingItemIndex].sayimId,
              DateFormat('yyyy-MM-dd').format(_selectedDate),
              _selectedDepartment.kod,
              barkodItem.masterGenelKod,
              barkodItem.barkod,
              barkodItem.masterAltbirim,
              quantity,
            );

            if (success) {
              setState(() {
                _sayimItems[existingItemIndex] = SayimItem(
                  sayimId: _sayimItems[existingItemIndex].sayimId,
                  sayimTarih: _sayimItems[existingItemIndex].sayimTarih,
                  sayimDepartman: _sayimItems[existingItemIndex].sayimDepartman,
                  sayimStokkod: _sayimItems[existingItemIndex].sayimStokkod,
                  sayimBarkod: barkodItem.barkod, // Yeni barkod ile güncelle
                  sayimAltbirim: _sayimItems[existingItemIndex].sayimAltbirim,
                  sayimMiktar: quantity.toDouble(),
                  sayimTipi: _sayimItems[existingItemIndex].sayimTipi,
                  depAd: _sayimItems[existingItemIndex].depAd,
                  masterAd: _sayimItems[existingItemIndex].masterAd,
                  sayimOrtalama: _sayimItems[existingItemIndex].sayimOrtalama,
                  sayimTutar: _sayimItems[existingItemIndex].sayimTutar,
                );
              });

              _showSuccessSnackBar(
                '${barkodItem.masterAd} miktarı güncellendi: $quantity',
              );
            } else {
              _showErrorSnackBar('Miktar güncelleme başarısız');
            }
          } else {
            // Yeni ürün ekle ve API'ye kaydet
            final success = await ApiService.saveSayimItem(
              token,
              selectedDatabase.id,
              0, // Yeni ürün için 0
              DateFormat('yyyy-MM-dd').format(_selectedDate),
              _selectedDepartment.kod,
              barkodItem.masterGenelKod,
              barkodItem.barkod,
              barkodItem.masterAltbirim,
              quantity,
            );

            if (success) {
              final newItem = SayimItem(
                sayimId: 0, // Yeni ürün için 0
                sayimTarih: DateFormat('yyyy-MM-dd').format(_selectedDate),
                sayimDepartman: _selectedDepartment.kod,
                sayimStokkod: barkodItem.masterGenelKod,
                sayimBarkod: barkodItem.barkod,
                sayimAltbirim: barkodItem.masterAltbirim,
                sayimMiktar: quantity.toDouble(),
                sayimTipi: 'S',
                depAd: _selectedDepartment.ad,
                masterAd: barkodItem.masterAd,
                sayimOrtalama: 0,
                sayimTutar: 0,
              );

              setState(() {
                _sayimItems.insert(0, newItem); // En üste ekle
              });

              _showSuccessSnackBar('${barkodItem.masterAd} eklendi: $quantity');
            } else {
              _showErrorSnackBar('Ürün ekleme başarısız');
            }
          }
        } else {
          // Value boş - barkod bulunamadı
          _showErrorSnackBar('Barkod bulunamadı: $barcode');
        }
      } else {
        _showErrorSnackBar('Barkod bulunamadı: $barcode');
      }
    } catch (e) {
      _showErrorSnackBar('Barkod kontrolü hatası: $e');
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

                    // Sayısal klavye
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
              Builder(
                builder: (dialogContext) {
                  final actionFontSize =
                      (Theme.of(dialogContext).textTheme.labelLarge?.fontSize ??
                              14) *
                          2;
                  final actionTextStyle = TextStyle(
                    fontSize: actionFontSize,
                    inherit: true,
                  );

                  final canSave = barcodeInputController.text.trim().isNotEmpty &&
                      finalQuantity > 0;

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
                              vertical: 24,
                              horizontal: 24,
                            ),
                            minimumSize: const Size.fromHeight(56),
                            textStyle: actionTextStyle,
                          ),
                          icon: Icon(Icons.close, size: actionFontSize * 1.15),
                          label: const Text('İptal'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: canSave
                              ? () async {
                                  final barcode =
                                      barcodeInputController.text.trim();
                                  Navigator.pop(context);
                                  await _processManualBarcode(
                                    barcode,
                                    finalQuantity,
                                  );
                                  _barcodeFocusNode.requestFocus();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 24,
                            ),
                            minimumSize: const Size.fromHeight(56),
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

  // Silme onayı dialogu (SayimItem için)
  void _showDeleteConfirmationDialog(SayimItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Silme Onayı',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.masterAd != null && item.masterAd!.isNotEmpty) ...[
                Text(
                  item.masterAd!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stok Kodu: ${item.sayimStokkod}'),
                    const SizedBox(height: 4),
                    Text('Barkod: ${item.sayimBarkod}'),
                    const SizedBox(height: 4),
                    Text(
                      'Miktar: ${item.sayimMiktar.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu ürünü silmek istediğinize emin misiniz?',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  flex: 30,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 70,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteItem(item);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Evet, Sil'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Silme işlemi
  Future<void> _deleteItem(SayimItem item) async {
    try {
      final token = await StorageService.getToken();
      final selectedDatabase = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      ).selectedDatabase;

      if (token == null || selectedDatabase == null) {
        _showErrorSnackBar('Token veya veritabanı bilgisi bulunamadı');
        return;
      }

      final success = await ApiService.deleteSayimItem(
        token,
        selectedDatabase.id,
        item.sayimId,
      );

      if (success) {
        _showSuccessSnackBar('Ürün başarıyla silindi');
        _loadInventory(); // Listeyi yenile
      } else {
        _showErrorSnackBar('Silme işlemi başarısız');
      }
    } catch (e) {
      _showErrorSnackBar('Hata: $e');
    }
  }

  // Düzeltme dialogu
  void _showProductQuantityDialog(SayimItem item) {
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
          final currentQuantity = item.sayimMiktar.toInt();
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
            title: Text('Miktar Düzelt - ${item.masterAd ?? "Ürün"}'),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.7,
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

                    // Sayısal klavye
                    _buildNumericKeyboard(
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
                      onPressed: finalQuantity > 0
                          ? () {
                              Navigator.pop(context);
                              _updateItem(item, finalQuantity.toString());
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

  // Sayısal klavye
  Widget _buildNumericKeyboard(
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
              _buildNumberButton(
                '1',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '2',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
                '4',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '5',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
                '7',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
                '8',
                addQuantityController,
                totalQuantityController,
                isAddQuantityFocused,
                setDialogState,
              ),
              _buildNumberButton(
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
              _buildNumberButton(
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

  Widget _buildNumberButton(
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

  // Üç modlu klavye (Barkod, Eklenecek, Toplam)
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

  // Güncelleme işlemi
  Future<void> _updateItem(SayimItem item, String miktarText) async {
    try {
      final miktar = int.tryParse(miktarText);
      if (miktar == null) {
        _showErrorSnackBar('Geçerli bir miktar giriniz');
        return;
      }

      final token = await StorageService.getToken();
      final selectedDatabase = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      ).selectedDatabase;

      if (token == null || selectedDatabase == null) {
        _showErrorSnackBar('Token veya veritabanı bilgisi bulunamadı');
        return;
      }

      final success = await ApiService.saveSayimItem(
        token,
        selectedDatabase.id,
        item.sayimId,
        DateFormat('yyyy-MM-dd').format(_selectedDate),
        _selectedDepartment.kod,
        item.sayimStokkod,
        item.sayimBarkod,
        item.sayimAltbirim,
        miktar,
      );

      if (success) {
        _showSuccessSnackBar('Ürün başarıyla güncellendi');
        _loadInventory(); // Listeyi yenile
      } else {
        _showErrorSnackBar('Güncelleme işlemi başarısız');
      }
    } catch (e) {
      _showErrorSnackBar('Hata: $e');
    }
  }

  // Başarı mesajı
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // Hata mesajı
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sol taraf - Ana içerik
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Ürün adı
                                    if (item.masterAd != null &&
                                        item.masterAd!.isNotEmpty) ...[
                                      Text(
                                        item.masterAd!,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Stok kodu
                                    if (item.sayimStokkod.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Stok: ${item.sayimStokkod}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    // Barkod
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
                                    const SizedBox(height: 8),

                                    // Alt satır - ID, Miktar, Birim
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'ID: ${item.sayimId}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Miktar: ${item.sayimMiktar.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (item.sayimAltbirim.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Birim: ${item.sayimAltbirim}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Sağ taraf - Butonlar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Düzelt button
                                  SizedBox(
                                    width: 120,
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showProductQuantityDialog(item),
                                      icon: const Icon(Icons.edit, size: 20),
                                      label: const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Text('Düzelt'),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade700,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Sil button
                                  SizedBox(
                                    width: 120,
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showDeleteConfirmationDialog(item),
                                      icon: const Icon(Icons.delete, size: 20),
                                      label: const Text('Sil'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
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

  // Tarih + departman seçimi artık seçim ekranında yapılıyor.

  Widget _buildMainWidget() {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          const AliceInspectorButton(),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              '${DateFormat('dd.MM.yyyy').format(_selectedDate)} · Dep: ${_selectedDepartment.kod} · ${_selectedDepartment.ad}',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildListButtonWidget(),
          _buildInventoryListWidget(),
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
        actions: const [AliceInspectorButton()],
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
