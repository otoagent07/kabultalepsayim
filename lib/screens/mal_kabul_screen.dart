import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/department.dart';
import '../models/mal_kabul_order_item.dart';
import '../providers/selected_database_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_dialogs.dart';

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
  String? _lastVergiNo;
  String? _lastEirsaliyeENo;
  String? _lastSenaryo;
  String? _lastBelgeEttn;
  final Map<int, Map<String, dynamic>> _existingStokHareketByBelgeSatirId = {};
  List<MalKabulOrderItem> _orderItems = [];
  bool _isLoadingOrder = false;
  bool _isSaving = false;
  bool _isLoadingStokBarkod = false;
  final Map<String, _StokBarkodItem> _stokBarkodIndex = {};
  final Map<String, _StokBarkodItem?> _rowMatchedStokBarkod = {};
  final Map<String, double> _acceptedQuantities = {};
  final Map<String, TextEditingController> _rowTextControllers = {};
  final Map<String, FocusNode> _rowTextFocusNodes = {};
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  // AppBar sadeleştirildi; global barkod focus'u kaldırıldı.

  bool get _isSiparisLike =>
      _girisTip == 'Sipariş No' || _girisTip == 'Mal Kabul Giriş';

  void _snack(
    String message, {
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(message),
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  void _showErrorSnackWithDetails({
    required String title,
    required Object error,
  }) {
    final detailText = _formatErrorDetails(error);
        _snack(
      title,
      action: SnackBarAction(
          label: 'Detay',
          onPressed: () {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      detailText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  String _formatErrorDetails(Object error) {
    if (error is ApiHttpException) {
      const encoder = JsonEncoder.withIndent('  ');
      final reqBody =
          error.requestBody == null ? '' : encoder.convert(error.requestBody);

      return [
        'REQUEST',
        '${error.method} ${error.uri}',
        '',
        'Headers:',
        ...error.requestHeaders.entries.map((e) => '${e.key}: ${e.value}'),
        if (reqBody.isNotEmpty) ...[
          '',
          'Body:',
          reqBody,
        ],
        '',
        'RESPONSE',
        'Status: ${error.statusCode}',
        'Body:',
        error.responseBody,
      ].join('\n');
    }

    return error.toString();
  }

  static const Map<String, String> _birimKodlari = {
    'NIU': 'ADET',
    'KGM': 'KİLOGRAM',
    'GRM': 'GRAM',
    'MTR': 'METRE',
    'LTR': 'LİTRE',
    'PA': 'PAKET (Packet)',
    'PK': 'PAKET (Pack)',
    'BX': 'KUTU',
    'CMT': 'SANTİMETRE',
    'MTQ': 'METREKÜP',
    'MTK': 'METREKARE',
    'ROLL': 'RULO',
    'SET': 'SET',
    'CMQ': 'SANTİMETREKÜP',
  };

  String _displayBirim(String kod) {
    final raw = kod.trim();
    if (raw.isEmpty) return raw;
    if (_isSiparisLike) return raw;
    return _birimKodlari[raw.toUpperCase()] ?? raw;
  }

  void _showCurlRequestDialog({
    required String title,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Object? jsonBody,
  }) {
    final headerLines =
        headers.entries.map((e) => "--header '${e.key}: ${e.value}'").toList();

    String bodyPart = '';
    if (jsonBody != null) {
      const encoder = JsonEncoder.withIndent('  ');
      final pretty = encoder.convert(jsonBody);
      // curl single-quote escaping
      final escaped = pretty.replaceAll("'", r"'\''");
      bodyPart = " \\\n--data '$escaped'";
    }

    final curl = [
      "curl --location '${uri.toString()}' \\",
      ...headerLines.map((l) => '$l \\'),
      '--request $method$bodyPart',
    ].join('\n');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              curl,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _prettyUnit(String unit) {
    final u = unit.trim();
    if (u.isEmpty) return '';
    final lower = u.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }

  Widget _metricText({
    required String label,
    required String value,
    required Color color,
  }) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.black),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: color.withValues(alpha: 0.95),
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
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
    if (_orderNumberController.text.trim().isEmpty) {
      if (_isSiparisLike) {
        _orderNumberController.text = '13';
      } else {
        _orderNumberController.text = '90cb2492-c6ef-4c7b-b44e-9b3359259c5d';
      }
    }

    // Stok barkod listesini baştan çek (eşleştirme için)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadStokBarkodIndex();
    });
  }

  Future<void> _preloadStokBarkodIndex() async {
    if (_isLoadingStokBarkod || _stokBarkodIndex.isNotEmpty) return;
    setState(() => _isLoadingStokBarkod = true);
    try {
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();
      final dbId = databaseProvider.selectedDatabase?.id;
      if (token == null || dbId == null) return;

      final uri = Uri.parse(
        'https://backapis.rmosweb.com/api/Stok_Barkod/GetAll?Db_Id=$dbId',
      );
      final res = await http.get(
        uri,
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(res.body);
        final value = (jsonData['value'] as List<dynamic>?) ?? const [];
        for (final e in value) {
          final item = _StokBarkodItem.fromJson(e as Map<String, dynamic>);
          if (item.barkod.isNotEmpty) {
            _stokBarkodIndex[item.barkod] = item;
          }
        }
      }
    } catch (_) {
      // Sessiz geç: sadece UI eşleştirmesi için.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStokBarkod = false;
          // Index yüklendikten sonra tesellum match'lerini güncelle
          if (_orderItems.isNotEmpty) _applyTesellumData();
        });
      }
    }
  }

  String _mapBarcodeToStokkodIfAny(String barcode) {
    return _stokBarkodIndex[barcode]?.stokkod ?? barcode;
  }

  void _applyRowBarcodeMatch({
    required MalKabulOrderItem rowItem,
    required String scannedBarcode,
  }) {
    final matched = _stokBarkodIndex[scannedBarcode];
    setState(() {
      _rowMatchedStokBarkod[rowItem.stokkod] = matched;
    });
  }

  /// Sipariş No akışında: Tesellum_Mevcut == true olan satırları
  /// barkod okutulmuş + miktar set edilmiş olarak işaretle.
  void _applyTesellumData() {
    for (final item in _orderItems) {
      if (!item.tesellumMevcut) continue;

      // Kabul miktarını tesellum miktarına set et
      _acceptedQuantities[item.stokkod] = item.tesellumMiktar;

      // Barkod alanını doldur
      final barkod = (item.tesellumBarkod ?? '').trim();
      if (barkod.isNotEmpty) {
        final c = _rowTextControllers.putIfAbsent(
          item.stokkod,
          () => TextEditingController(),
        );
        c.text = barkod;

        // Barkod index'te eşleşme varsa matched olarak işaretle
        final matched = _stokBarkodIndex[barkod];
        _rowMatchedStokBarkod[item.stokkod] = matched;
      }
    }
  }

  void _applyExistingStokHareketForEttn(List<Map<String, dynamic>> rows) {
    _existingStokHareketByBelgeSatirId.clear();
    for (final r in rows) {
      final raw = r['BelgeSatirId'];
      final id = raw is int ? raw : int.tryParse('$raw');
      if (id == null) continue;
      _existingStokHareketByBelgeSatirId[id] = r;
    }

    for (final item in _orderItems) {
      final existing = _existingStokHareketByBelgeSatirId[item.id];
      if (existing == null) continue;

      final barkod = (existing['Barkod'] ?? '').toString().trim();
      if (barkod.isNotEmpty) {
        final c = _rowTextControllers.putIfAbsent(
          item.stokkod,
          () => TextEditingController(),
        );
        c.text = barkod;

        final matched = _stokBarkodIndex[barkod];
        _rowMatchedStokBarkod[item.stokkod] = matched;
      }

      final miktarRaw = existing['Miktar'];
      final miktar =
          miktarRaw is num ? miktarRaw.toDouble() : double.tryParse('$miktarRaw');
      if (miktar != null) {
        _acceptedQuantities[item.stokkod] = miktar;
      }
    }
  }

  Future<void> _deleteTesellum({
    required MalKabulOrderItem item,
  }) async {
    final tesellumId = item.tesellumId;
    final ok = await AppDialogs.confirm(
      context,
      title: 'Silme Onayı',
      message: 'Kayıtlı: #$tesellumId silinsin mi?',
      cancelText: 'Vazgeç',
      confirmText: 'Evet',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;

    try {
      if (mounted) setState(() => _isLoadingOrder = true);

      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();
      final backDbId =
          databaseProvider.selectedDatabase?.dbBackOfficeId ??
              databaseProvider.selectedDatabase?.id;

      if (token == null || backDbId == null) {
        throw Exception('Token/Db_Id bulunamadı');
      }

      await ApiService.deleteStokHareketById(
        token: token,
        dbId: backDbId,
        id: tesellumId,
      );

      _snack('Silindi', backgroundColor: Colors.green);

      if (mounted) await _loadOrder();
    } catch (e) {
      if (mounted) _showErrorSnackWithDetails(title: 'Silme hatası', error: e);
    } finally {
      if (mounted) setState(() => _isLoadingOrder = false);
    }
  }

  Future<void> _deleteExistingStokHareket({
    required int existingId,
    required String ettn,
    required MalKabulOrderItem item,
  }) async {
    final ok = await AppDialogs.confirm(
      context,
      title: 'Silme Onayı',
      message: 'Kayıtlı: #$existingId silinsin mi?',
      cancelText: 'Vazgeç',
      confirmText: 'Evet',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;

    try {
      if (mounted) {
        setState(() => _isLoadingOrder = true);
      }
      final databaseProvider = Provider.of<SelectedDatabaseProvider>(
        context,
        listen: false,
      );
      final token = await StorageService.getToken();
      final backDbId =
          databaseProvider.selectedDatabase?.dbBackOfficeId ??
              databaseProvider.selectedDatabase?.id;

      if (token == null || backDbId == null) {
        throw Exception('Token/Db_Id bulunamadı');
      }

      await ApiService.deleteStokHareketById(
        token: token,
        dbId: backDbId,
        id: existingId,
      );

      final existing = await ApiService.getStokHareketByEttn(
        token: token,
        dbId: backDbId,
        ettn: ettn,
      );

      if (!mounted) return;
      setState(() {
        // Endpoint sonucu ne diyorsa UI onu göstersin: gerçekten silindi mi?
        final stillExists = existing.any((r) {
          final rawBelgeSatirId = r['BelgeSatirId'];
          final belgeSatirId = rawBelgeSatirId is int
              ? rawBelgeSatirId
              : int.tryParse('$rawBelgeSatirId');

          if (belgeSatirId == null || belgeSatirId != item.id) return false;

          final rawId = r['Id'];
          final id = rawId is int ? rawId : int.tryParse('$rawId');

          // Servis sadece BelgeSatirId döndürüyorsa yine de "var" say.
          return id == null ? true : id == existingId;
        });

        if (!stillExists) {
          // Silindiği doğrulandı: satırı "okutulmamış" hale getir.
          _rowMatchedStokBarkod[item.stokkod] = null;
          _rowTextControllers[item.stokkod]?.clear();
          _existingStokHareketByBelgeSatirId.remove(item.id);
        }
        _applyExistingStokHareketForEttn(existing);
      });

      final stillExists = existing.any((r) {
        final rawBelgeSatirId = r['BelgeSatirId'];
        final belgeSatirId = rawBelgeSatirId is int
            ? rawBelgeSatirId
            : int.tryParse('$rawBelgeSatirId');
        if (belgeSatirId == null || belgeSatirId != item.id) return false;

        final rawId = r['Id'];
        final id = rawId is int ? rawId : int.tryParse('$rawId');
        return id == null ? true : id == existingId;
      });

            _snack(
        stillExists ? 'Silinemedi (kayıt listede hâlâ var)' : 'Silindi',
        backgroundColor: stillExists ? Colors.orange : Colors.green,
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackWithDetails(title: 'Silme hatası', error: e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _rowTextControllers.values) {
      c.dispose();
    }
    for (final f in _rowTextFocusNodes.values) {
      f.dispose();
    }
    _orderNumberController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _clearRowScanMemory() {
    for (final c in _rowTextControllers.values) {
      c.dispose();
    }
    for (final f in _rowTextFocusNodes.values) {
      f.dispose();
    }
    _rowTextControllers.clear();
    _rowTextFocusNodes.clear();
    _rowMatchedStokBarkod.clear();
    _existingStokHareketByBelgeSatirId.clear();
  }

  Future<void> _loadOrder() async {
    if (_orderNumberController.text.trim().isEmpty) {
            _snack('Lütfen sipariş numarası girin', backgroundColor: Colors.orange);
      return;
    }

    // Sipariş getirmeden önce klavyeyi kapat.
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() {
      // Listele'de önce ekranı temizle ki "gelmedi" anlaşılsın.
      _orderItems.clear();
      _acceptedQuantities.clear();
      _clearRowScanMemory();
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
            _applyTesellumData();
          });

          // Log the IDs from the fetched order
          for (var item in _orderItems) {
          }

          if (mounted) {
            _snack('${response.value.length} ürün yüklendi', backgroundColor: Colors.green);
          }
        } else {
          if (mounted) {
            _snack(
              'Sipariş yüklenemedi: ${response.message ?? 'Bilinmeyen hata'}',
              backgroundColor: Colors.red,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
                _snack('Sipariş yükleme hatası: $e', backgroundColor: Colors.red);
      }
    }

    setState(() {
      _isLoadingOrder = false;
    });
  }

  Future<void> _loadByEttn() async {
    final ettn = _orderNumberController.text.trim();
    if (ettn.isEmpty) {
            _snack('Lütfen ETTN girin/okutun', backgroundColor: Colors.orange);
      return;
    }
    if (_efaturaDbId == null) {
            _snack('Departmanda efatura Db_Id bulunamadı', backgroundColor: Colors.red);
      return;
    }
    if (_efatSirketId == null) {
            _snack('Departmanda EFat_SirketID bulunamadı', backgroundColor: Colors.red);
      return;
    }

    // Listele'de önce ekranı temizle ki "gelmedi" anlaşılsın.
    if (mounted) {
      setState(() {
        _orderItems.clear();
        _acceptedQuantities.clear();
        _clearRowScanMemory();
      });
    } else {
      _orderItems.clear();
      _acceptedQuantities.clear();
      _clearRowScanMemory();
    }

    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    setState(() => _isLoadingOrder = true);
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final response = await ApiService.getBelgeByEttnGelen(
        token: token,
        efaturaDbId: _efaturaDbId!,
        sirketId: _efatSirketId!,
        ettn: ettn,
        detay: true,
        isFatura: _girisTip == 'Fatura',
      );

      if (response.isSucceded) {
        setState(() {
          _orderItems = response.toMalKabulOrderItems();
          _acceptedQuantities.clear();
          for (final item in _orderItems) {
            _acceptedQuantities[item.stokkod] = item.miktar;
          }
          _lastVergiNo = response.value?.vergino;
          _lastEirsaliyeENo = response.value?.eirsaliyeENo;
          _lastSenaryo = response.value?.senaryo;
          _lastBelgeEttn = (response.value?.entegreEttn ??
                  response.value?.ettn ??
                  '')
              .trim();
        });

        // Eğer backoffice tarafında bu ETTN ile daha önce InsertBarkod yapıldıysa,
        // ilgili satırları barkod okutulmuş gibi işaretle.
        try {
          final databaseProvider = Provider.of<SelectedDatabaseProvider>(
            context,
            listen: false,
          );
          final backDbId =
              databaseProvider.selectedDatabase?.dbBackOfficeId ??
                  databaseProvider.selectedDatabase?.id;
          if (backDbId != null) {
            final existing = await ApiService.getStokHareketByEttn(
              token: token,
              dbId: backDbId,
              ettn: ettn,
            );
            if (mounted) {
              setState(() {
                _applyExistingStokHareketForEttn(existing);
              });
            }
          }
        } catch (e) {
          if (mounted) {
            _showErrorSnackWithDetails(
              title: 'StokHareket(GetByETTN) okuma hatası',
              error: e,
            );
          }
        }
        if (mounted) {
          final headers = <String, String>{
            'accept': 'application/json',
            'Authorization': 'Bearer {token}',
          };
          final endpointPath = _girisTip == 'Fatura'
              ? '/api/Fatura/GetByETTN_Gelen'
              : '/api/Irsaliye/GetByETTN_Gelen';
          final uri = Uri.parse('${ApiService.efaturaApiBaseUrl}$endpointPath').replace(
            queryParameters: <String, String>{
              'Db_Id': _efaturaDbId!.toString(),
              'sirketId': _efatSirketId!.toString(),
              'ETTN': ettn,
              'detay': 'true',
            },
          );

          final hasZero = _orderItems.isEmpty;
        _snack(
            '${_orderItems.length} satır yüklendi (${_girisTip == 'Fatura' ? 'Fatura' : 'İrsaliye'})',
            backgroundColor: Colors.green,
            action: hasZero
                  ? SnackBarAction(
                      label: 'Göster',
                      onPressed: () {
                        if (!mounted) return;
                        _showCurlRequestDialog(
                          title: 'ETTN Listele - CURL',
                          method: 'GET',
                          uri: uri,
                          headers: headers,
                        );
                      },
                    )
                  : null,
          );
        }
      } else {
        if (mounted) {
        _snack(response.message ?? 'İrsaliye/Fatura yüklenemedi', backgroundColor: Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackWithDetails(title: 'İrsaliye/Fatura yükleme hatası', error: e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  // Tarih seçimi artık seçim ekranında yapılıyor.

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
                          onPressed: () {
                            if (_isLoadingStokBarkod) {
                                                _snack(
                                'Barkodlar yükleniyor, lütfen bekleyiniz...',
                                backgroundColor: Colors.orange,
                              );
                              return;
                            }
                            if (_stokBarkodIndex.isEmpty) {
                                                _snack('Yüklü barkod bulunamadı', backgroundColor: Colors.red);
                              return;
                            }

                            String searchQuery = '';
                            var allItems = _stokBarkodIndex.values.toList();
                            allItems.sort((a, b) => a.barkod.compareTo(b.barkod));
                            var filteredItems = allItems;

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (sheetContext) => StatefulBuilder(
                                builder: (sheetContext, setSheetState) {
                                  return Container(
                                    height:
                                        MediaQuery.of(sheetContext).size.height *
                                            0.85,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.qr_code_2,
                                                    color: Colors.blue[700],
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    'Yüklenen Barkodlar',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        16,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '${filteredItems.length} kayıt',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    elevation: 1,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        10,
                                                      ),
                                                    ),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.red,
                                                      ),
                                                      tooltip: 'Kapat',
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                        sheetContext,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              TextField(
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'Barkod ile arayın...',
                                                  prefixIcon: Icon(
                                                    Icons.search,
                                                    color: Colors.grey[600],
                                                  ),
                                                  suffixIcon:
                                                      searchQuery.isNotEmpty
                                                          ? IconButton(
                                                              icon: Icon(
                                                                Icons.clear,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                              onPressed: () {
                                                                setSheetState(
                                                                    () {
                                                                  searchQuery =
                                                                      '';
                                                                  filteredItems =
                                                                      allItems;
                                                                });
                                                              },
                                                            )
                                                          : null,
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      12,
                                                    ),
                                                    borderSide:
                                                        BorderSide.none,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 16,
                                                    vertical: 12,
                                                  ),
                                                ),
                                                onChanged: (value) {
                                                  setSheetState(() {
                                                    searchQuery =
                                                        value.toLowerCase();
                                                    filteredItems = allItems
                                                        .where(
                                                          (x) => x.barkod
                                                              .toLowerCase()
                                                              .contains(
                                                                searchQuery,
                                                              ),
                                                        )
                                                        .toList();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: filteredItems.isEmpty
                                              ? Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.search_off,
                                                        size: 64,
                                                        color: Colors.grey[400],
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      Text(
                                                        'Kayıt bulunamadı',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: Colors
                                                              .grey[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : ListView.builder(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  itemCount:
                                                      filteredItems.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final x =
                                                        filteredItems[index];
                                                    return Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                        bottom: 8,
                                                      ),
                                                      child: Material(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        elevation: 1,
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                x.barkod,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Text(
                                                                x.stokAdi,
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .grey[700],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                x.stokkod,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
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
                                  );
                                },
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 9,
                              horizontal: 9,
                            ),
                            minimumSize: const Size.fromHeight(24),
                            textStyle: actionTextStyle,
                          ),
                          icon:
                              Icon(Icons.qr_code_2, size: actionFontSize * 1.15),
                          label: const Text('Yüklenen Barkodları Göster'),
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

  bool _isFaturaGiris() {
    final s = _girisTip.toLowerCase();
    return s.contains('fatura');
  }

  int _fatIRSValue() => _isFaturaGiris() ? 0 : 1;

  Map<String, dynamic> _buildInsertBarkodBody({
    required int dbId,
    required String cariKod,
    required String faturaNo,
    required String? siparisNo,
  }) {
    final tarihIso = DateTime.now().toIso8601String();

    final detay = <Map<String, dynamic>>[];
    for (final item in _orderItems) {
      final matched = _rowMatchedStokBarkod[item.stokkod];
      final rowTextController = _rowTextControllers[item.stokkod];
      final okutulanBarkod = (rowTextController?.text ?? '').trim().isNotEmpty
          ? rowTextController!.text.trim()
          : (matched?.barkod ?? '').trim();

      // InsertBarkod için stokKod yalnızca okutulan barkod eşleşmesinden gelmeli.
      // Barkod boşsa veya eşleşme yoksa stokKod boş gönderilir (fallback yok).
      final stokKod =
          okutulanBarkod.isEmpty ? '' : (matched?.stokkod ?? '').trim();
      if (stokKod.isEmpty) {
        continue;
      }
      final birim = (item.birim).trim();
      final miktar = _acceptedQuantities[item.stokkod] ?? item.miktar;

      const birimFiyat = 0;
      final tutar = miktar * birimFiyat;

      final belgeSatirId = item.id;
      final belgeEttn = (_lastBelgeEttn ?? '').trim();
      final existing = _existingStokHareketByBelgeSatirId[belgeSatirId];
      final existingIdRaw = existing?['Id'];
      final existingId =
          existingIdRaw is int ? existingIdRaw : int.tryParse('$existingIdRaw');

      detay.add({
        'Id': existingId ?? (item.tesellumId > 0 ? item.tesellumId : 0),
        'barkod': okutulanBarkod,
        'stokKod': stokKod,
        'BelgeETTN': belgeEttn,
        'BelgeSatirId': belgeSatirId,
        'birim': birim,
        'miktar': miktar,
        'birimFiyat': birimFiyat,
        'tutar': tutar,
        'netTutar': tutar,
        'TalepId': belgeSatirId,
      });
    }

    final body = <String, dynamic>{
      'db_Id': dbId,
      'tarih': tarihIso,
      'cari': cariKod,
      'fatIRS': _fatIRSValue(),
      'faturaNo': faturaNo,
      'subeKodu': _selectedDepartment.sube,
      'anaDepo': _selectedDepartment.kod,
      'detaylar': detay,
    };

    // e-fatura ise sadece senaryo bilgisini (varsa) ekle
    final senaryo = (_lastSenaryo ?? '').trim();
    if (senaryo.isNotEmpty) {
      body['senaryo'] = senaryo;
    }

    // sipariş ise siparisNo ekle
    final sNo = (siparisNo ?? '').trim();
    if (sNo.isNotEmpty) {
      body['Siparisno'] = sNo;
    }

    return body;
  }

  Future<bool> _showInsertBarkodPreviewDialog({
    required Map<String, dynamic> body,
    required String cariKod,
    required String faturaNo,
  }) async {
    final curl = [
      "curl -X POST 'https://backapis.rmosweb.com/api/StokHareket/InsertBarkod' \\",
      "-H 'Content-Type: application/json' \\",
      "-H 'Authorization: Bearer {token}' \\",
      "-d '{JSON_BODY}'",
    ].join('\n');

    final mappingLines = <String>[
      'cari → HesapPlan.Kod (GetAllByVergiNo endpointinden alındı)',
      'faturaNo → Eirsaliye_ENo (GetByETTN_Gelen)',
      'fatIRS → kullanıcı seçimi (Fatura/Irsaliye)',
      'subeKodu → departman seçimi',
      'anaDepo → depo seçimi',
      'barkod → okutulan değer',
      'stokKod → barkod sorgusundan geldi',
      'miktar → kullanıcı input',
    ];

    final d = body['detaylar'];
    final sentCount = d is List ? d.length : 0;
    final skipped = _orderItems.length - sentCount;
    final note = skipped > 0
        ? 'Not: stokKod boş olduğu için $skipped satır gönderilmeyecek.'
        : null;

    return await AppDialogs.requestPreview(
      context,
      title: 'Gönderim Önizleme',
      curlPreview: curl,
      jsonBody: body,
      mappingLines: mappingLines,
      note: note,
      cancelText: 'İptal',
      confirmText: 'Gönder',
    );
  }

  Future<bool> _showMalKabulPreviewDialog({
    required Map<String, dynamic> body,
    required String refNo,
    required int satirCount,
  }) async {
    final curl = [
      "curl -X POST 'https://backapis.rmosweb.com/api/MalKabul/Insert' \\",
      "-H 'Content-Type: application/json' \\",
      "-H 'Authorization: Bearer {token}' \\",
      "-d '{JSON_BODY}'",
    ].join('\n');

    final mappingLines = <String>[
      'db_Id → seçili db',
      'Tarih → seçilen tarih',
      'RefTip → S (Sipariş)',
      'RefNo → sipariş no',
      'Satirlar[].EfatId → sipariş satır id',
      'Satirlar[].Miktar → kullanıcı input',
    ];

    return await AppDialogs.requestPreview(
      context,
      title: 'Gönderim Önizleme',
      curlPreview: curl,
      jsonBody: body,
      mappingLines: mappingLines,
      note: 'Özet: refNo=$refNo, satır=$satirCount',
      cancelText: 'İptal',
      confirmText: 'Gönder',
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
    if (!_isSiparisLike) {
      _orderNumberController.text = barcode;
      _loadByEttn();
            _snack('ETTN: $barcode', backgroundColor: Colors.blue);
      return;
    }
    // Check if barcode is a number (order number)
    final orderNumber = int.tryParse(barcode);
    if (orderNumber != null) {
      // Barcode is a number, treat it as order number
      _orderNumberController.text = barcode;
      _loadOrder();
            _snack('Sipariş numarası: $barcode', backgroundColor: Colors.blue);
      return;
    }

    // If order is not loaded yet, show message
    if (_orderItems.isEmpty) {
            _snack('Önce sipariş yükleyin. Barkod: $barcode', backgroundColor: Colors.orange);
      return;
    }

    final effectiveStokkod = _mapBarcodeToStokkodIfAny(barcode);
    // Find matching item in order
    final matchingItem = _orderItems.firstWhere(
      (item) => item.stokkod == effectiveStokkod,
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
        tesellumId: 0,
        tesellumMiktar: 0,
        tesellumMevcut: false,
        tesellumBarkod: null,
      ),
    );

    if (matchingItem.stokkod.isNotEmpty) {
      setState(() {
        _acceptedQuantities[matchingItem.stokkod] = quantity;
      });
            _snack('Miktar güncellendi: $quantity', backgroundColor: Colors.green);
    } else {
            _snack('Barkod bulunamadı: $barcode', backgroundColor: Colors.red);
    }
  }

  void _processBarcode(String barcode) {
    if (!_isSiparisLike) {
      _orderNumberController.text = barcode;
      _loadByEttn();
            _snack('ETTN: $barcode', backgroundColor: Colors.blue);
      return;
    }
    // Check if barcode is a number (order number)
    final orderNumber = int.tryParse(barcode);
    if (orderNumber != null) {
      // Barcode is a number, treat it as order number
      _orderNumberController.text = barcode;
      _loadOrder();
            _snack('Sipariş numarası: $barcode', backgroundColor: Colors.blue);
      return;
    }

    // If order is not loaded yet, show message
    if (_orderItems.isEmpty) {
            _snack('Önce sipariş yükleyin. Barkod: $barcode', backgroundColor: Colors.orange);
      return;
    }

    final effectiveStokkod = _mapBarcodeToStokkodIfAny(barcode);
    // Find matching item in order
    final matchingItem = _orderItems.firstWhere(
      (item) => item.stokkod == effectiveStokkod,
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
        tesellumId: 0,
        tesellumMiktar: 0,
        tesellumMevcut: false,
        tesellumBarkod: null,
      ),
    );

    if (matchingItem.stokkod.isNotEmpty) {
      _showQuantityDialog(matchingItem);
    } else {
            _snack('Barkod bulunamadı: $barcode', backgroundColor: Colors.red);
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
                                                        _snack(
                                    'Miktar güncellendi: $enteredQuantity',
                                    backgroundColor: Colors.green,
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
            _snack('Önce sipariş yükleyin', backgroundColor: Colors.orange);
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
        // Mal Kabul Giriş: malkabul/insert API
        if (_girisTip == 'Mal Kabul Giriş') {
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final refNo = _orderNumberController.text.trim();

          final satirlar = <Map<String, dynamic>>[];
          for (var item in _orderItems) {
            final acceptedQuantity = _acceptedQuantities[item.stokkod] ?? item.miktar;
            satirlar.add({
              'Id': 0,
              'EfatId': item.id,
              'Sira': 0,
              'UrunAdi': 'Ürün ${item.stokkod}',
              'Firma': 'Tedarikçi',
              'Miktar': acceptedQuantity,
              'Birim': item.birim,
              'PartiNo': '${item.id}-${DateTime.now().millisecondsSinceEpoch}',
              'SonKullanimTarih': DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 365))),
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

          const encoder = JsonEncoder.withIndent('  ');
          developer.log(encoder.convert(requestBody), name: 'MAL_KABUL_REQUEST_JSON');

          final ok = await _showMalKabulPreviewDialog(
            body: requestBody,
            refNo: refNo,
            satirCount: satirlar.length,
          );
          if (!ok) {
            if (mounted) setState(() => _isSaving = false);
            return;
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

          developer.log('isSucceded: ${response['isSucceded']}', name: 'MAL_KABUL_RESPONSE');
          developer.log('message: ${response['message']}', name: 'MAL_KABUL_RESPONSE');
          developer.log('messageList: ${response['messageList']}', name: 'MAL_KABUL_RESPONSE');
          developer.log('value: ${response['value']}', name: 'MAL_KABUL_RESPONSE');

          if (response['isSucceded'] == true) {
            if (mounted) {
                _snack('Mal Kabul kaydedildi', backgroundColor: Colors.green);
              setState(() {
                _orderItems.clear();
                _acceptedQuantities.clear();
                _orderNumberController.text = refNo;
              });
              await _loadOrder();
            }
          } else {
            if (mounted) {
                _snack(response['message'] ?? 'Bilinmeyen hata', backgroundColor: Colors.red);
            }
          }
        } else {
          // İrsaliye / Fatura / Sipariş No: insertBarkod API
          // Sipariş No: cari = seciliSatici (ilk satırdan), faturaNo boş, siparisNo = sipariş numarası
          // İrsaliye / Fatura: cari = HesapPlan.Kod (vergiNo'dan), faturaNo = Eirsaliye_ENo, siparisNo yok
          final backDbId = databaseProvider.selectedDatabase!.dbBackOfficeId ??
              databaseProvider.selectedDatabase!.id;

          final String cariKod;
          final String faturaNo;
          final String? siparisNo;

          if (_girisTip == 'Sipariş No') {
            cariKod = _orderItems.isNotEmpty ? _orderItems.first.seciliSatici.trim() : '';
            faturaNo = '';
            siparisNo = _orderNumberController.text.trim();
          } else {
            final vergino = (_lastVergiNo ?? '').trim();
            if (vergino.isEmpty) {
              throw Exception('ETTN sorgusundan Vergino alınamadı');
            }
            cariKod = await ApiService.getHesapPlanKodByVergiNo(
                  token: token,
                  dbId: backDbId,
                  vergino: vergino,
                ) ?? '';
            if (cariKod.trim().isEmpty) {
              throw Exception('HesapPlan.Kod bulunamadı (vergino: $vergino)');
            }
            faturaNo = (_lastEirsaliyeENo ?? '').trim();
            if (faturaNo.isEmpty) {
              throw Exception('ETTN sorgusundan Eirsaliye_ENo alınamadı');
            }
            siparisNo = null;
          }

          final body = _buildInsertBarkodBody(
            dbId: backDbId,
            cariKod: cariKod,
            faturaNo: faturaNo,
            siparisNo: siparisNo,
          );
          final detaylar = body['detaylar'];
          if (detaylar is! List || detaylar.isEmpty) {
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            size: 36,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Gönderilecek Satır Yok',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Hiçbir satırda barkod eşleşmesi bulunamadı.\nGöndermek için önce satırlara barkod okutun.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Anladım',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              setState(() => _isSaving = false);
            }
            return;
          }

          final ok = await _showInsertBarkodPreviewDialog(
            body: body,
            cariKod: cariKod,
            faturaNo: faturaNo,
          );
          if (!ok) {
            if (mounted) setState(() => _isSaving = false);
            return;
          }

          final response = await ApiService.insertStokHareketBarkod(
            token: token,
            body: body,
          );

          final isOk = response['isSucceded'] == true;
          final msg = (response['message'] ?? (isOk ? 'Gönderildi' : 'Gönderim hatası')).toString();

          if (mounted) {
            _snack(msg, backgroundColor: isOk ? Colors.green : Colors.red);
          }

          final refValue = _orderNumberController.text.trim();

          if (isOk && mounted) {
            setState(() {
              _orderItems.clear();
              _acceptedQuantities.clear();
              _orderNumberController.text = refValue;
              _lastVergiNo = null;
              _lastEirsaliyeENo = null;
              _lastSenaryo = null;
              _lastBelgeEttn = null;
              _existingStokHareketByBelgeSatirId.clear();
            });
          }

          if (mounted) setState(() => _isSaving = false);

          if (isOk && mounted && refValue.isNotEmpty) {
            if (_girisTip == 'Sipariş No') {
              await _loadOrder();
            } else {
              await _loadByEttn();
            }
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackWithDetails(title: 'Gönderim/Kaydetme hatası', error: e);
      }
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSiparis = _isSiparisLike;
    final titleLabel = isSiparis ? 'Sipariş No' : 'ETTN';
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 112,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          iconSize: 28,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Geri',
        ),
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mal Kabul — $_girisTip',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Card(
              margin: const EdgeInsets.only(right: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _orderNumberController,
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: titleLabel,
                        ),
                        keyboardType:
                            isSiparis ? TextInputType.number : TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_isLoadingOrder) return;
                          if (isSiparis) {
                            _loadOrder();
                          } else {
                            _loadByEttn();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_orderNumberController.text.trim().isNotEmpty) ...[
                      IconButton(
                        tooltip: 'Temizle',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _orderNumberController.clear();
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    FilledButton.tonalIcon(
                      onPressed: _isLoadingOrder
                          ? null
                          : (isSiparis ? _loadOrder : _loadByEttn),
                      icon:
                          _isLoadingOrder
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.list_alt_outlined),
                      label: Text(
                        'Listele',
                        style: TextStyle(
                          fontSize:
                              (Theme.of(context).textTheme.labelLarge?.fontSize ??
                                      14) *
                                  0.85,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: Column(
        children: [
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                    itemCount: _orderItems.length,
                    itemBuilder: (context, index) {
                      final item = _orderItems[index];
                      final acceptedQuantity =
                          _acceptedQuantities[item.stokkod] ?? item.miktar;
                      final rowTextController = _rowTextControllers.putIfAbsent(
                        item.stokkod,
                        () => TextEditingController(),
                      );
                      final rowTextFocusNode = _rowTextFocusNodes.putIfAbsent(
                        item.stokkod,
                        () => FocusNode(debugLabel: 'RowTextField:${item.stokkod}'),
                      );
                      final matched = _rowMatchedStokBarkod[item.stokkod];
                      final ettnForRefresh = _orderNumberController.text.trim();
                      final existing =
                          _existingStokHareketByBelgeSatirId[item.id];
                      final existingIdRaw = existing?['Id'];
                      final existingId = existingIdRaw is int
                          ? existingIdRaw
                          : int.tryParse('$existingIdRaw');

                      final orderQtyStr = item.miktar.toStringAsFixed(0);
                      final acceptedQtyStr =
                          acceptedQuantity.toStringAsFixed(0);
                      final priceStr = item.seciliFiyat.toStringAsFixed(2);
                      final tesellumMevcut = item.tesellumMevcut;
                      final tesellumBarkod = (item.tesellumBarkod ?? '').trim();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        elevation: 1,
                        color: tesellumMevcut
                            ? Colors.green.shade50
                            : matched != null
                                ? const Color(0xFFFFFDF5)
                                : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Barkod:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: rowTextController,
                                          focusNode: rowTextFocusNode,
                                          keyboardType: TextInputType.none,
                                          textInputAction: TextInputAction.none,
                                          maxLines: 1,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip: 'Temizle',
                                              icon: const Icon(Icons.close),
                                              onPressed: () {
                                                rowTextController.clear();
                                                setState(() {
                                                  _rowMatchedStokBarkod[
                                                      item.stokkod] = null;
                                                });
                                                rowTextFocusNode.requestFocus();
                                              },
                                            ),
                                          ),
                                          onChanged: (value) {
                                            if (value.endsWith('\n')) {
                                              final barcode =
                                                  value.replaceAll('\n', '').trim();
                                              if (barcode.isNotEmpty) {
                                                rowTextController.text = barcode;
                                                rowTextController.selection =
                                                    TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset: barcode.length,
                                                  ),
                                                );
                                                _applyRowBarcodeMatch(
                                                  rowItem: item,
                                                  scannedBarcode: barcode,
                                                );
                                              }
                                            }
                                          },
                                          onSubmitted: (value) {
                                            final barcode = value.trim();
                                            if (barcode.isNotEmpty) {
                                              rowTextController.text = barcode;
                                              rowTextController.selection =
                                                  TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: barcode.length,
                                                ),
                                              );
                                              _applyRowBarcodeMatch(
                                                rowItem: item,
                                                scannedBarcode: barcode,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Card(
                                            elevation: 2,
                                            margin: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () => _editQuantity(item),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: const [
                                                    Icon(Icons.edit, size: 18),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Düzenle',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (tesellumMevcut) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Sil',
                                              onPressed: () => _deleteTesellum(item: item),
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ] else if (existingId != null &&
                                              existingId > 0) ...[
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Sil',
                                              onPressed: () {
                                                if (ettnForRefresh.isEmpty) return;
                                                _deleteExistingStokHareket(
                                                  existingId: existingId,
                                                  ettn: ettnForRefresh,
                                                  item: item,
                                                );
                                              },
                                              icon: const Icon(Icons.delete_outline),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (matched != null) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          matched.stokAdi.isEmpty
                                              ? '(StokAd yok)'
                                              : matched.stokAdi,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          matched.stokkod.isEmpty
                                              ? '(StokKod yok)'
                                              : matched.stokkod,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (tesellumMevcut) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle, size: 13, color: Colors.white),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Kayıtlı #${item.tesellumId}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (tesellumBarkod.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        tesellumBarkod,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ] else if (existingId != null && existingId > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Kayıtlı: #$existingId',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
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
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _metricText(
                                      label: 'Sipariş',
                                      value:
                                          '$orderQtyStr ${_prettyUnit(_displayBirim(item.birim))}',
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Expanded(
                                    child: _metricText(
                                      label: 'Kabul',
                                      value: tesellumMevcut
                                          ? '${item.tesellumMiktar.toStringAsFixed(0)} ${_prettyUnit(_displayBirim(item.birim))}'
                                          : '$acceptedQtyStr ${_prettyUnit(_displayBirim(item.birim))}',
                                      color: Colors.green,
                                    ),
                                  ),
                                  Expanded(
                                    child: _metricText(
                                      label: 'Fiyat',
                                      value: priceStr,
                                      color: Colors.orange,
                                    ),
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
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
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

class _StokBarkodItem {
  final String stokkod;
  final String barkod;
  final String stokAdi;

  const _StokBarkodItem({
    required this.stokkod,
    required this.barkod,
    required this.stokAdi,
  });

  factory _StokBarkodItem.fromJson(Map<String, dynamic> json) {
    return _StokBarkodItem(
      stokkod: (json['B_Stokkod'] ?? '').toString().trim(),
      barkod: (json['B_Barkod'] ?? '').toString().trim(),
      stokAdi: (json['StokAdi'] ?? '').toString().trim(),
    );
  }
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
                                ? FutureBuilder<CameraFacing?>(
                                    future: controller?.getCameraInfo(),
                                    builder: (context, snapshot) {
                                      final facing = snapshot.data;
                                      if (facing != null) {
                                        return Text('Kamera: ${facing.name}');
                                      }
                                      return const Text('Kamera: Yükleniyor...');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 5),
          content: Text('Kamera izni gerekli'),
        ),
      );
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
