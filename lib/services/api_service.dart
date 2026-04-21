import 'dart:convert';
import 'package:http/http.dart' as http;
import 'alice_http_client.dart';
import '../models/login_response.dart';
import '../models/department_response.dart';
import '../models/sayim_response.dart';
import '../models/barkod_kontrol_response.dart';
import '../models/sube_response.dart';
import '../models/stok_master_response.dart';
import '../models/stok_birim_fiyat_response.dart';
import '../models/mal_kabul_order_response.dart';
import '../models/mal_kabul_save_item.dart';
import '../models/efatura_irsaliye_response.dart';

class ApiHttpException implements Exception {
  final String method;
  final Uri uri;
  final Map<String, String> requestHeaders;
  final Object? requestBody;
  final int statusCode;
  final String responseBody;

  ApiHttpException({
    required this.method,
    required this.uri,
    required this.requestHeaders,
    required this.requestBody,
    required this.statusCode,
    required this.responseBody,
  });

  @override
  String toString() => 'HTTP $statusCode $method $uri';
}

class ApiService {
  static final _client = AliceHttpClient();

  static const String baseUrl = 'https://service.rmosweb.com';
  static const String backApiBaseUrl = 'https://backapi.rmosweb.com';
  static const String efaturaApiBaseUrl = 'https://efaturaapi.rmosweb.com';
  static const String tokenEndpoint = '/security/createToken';
  static const String loginByTokenEndpoint = '/api/Users/LoginByToken';
  static const String departmentsEndpoint =
      '/api/StokKodlar/GetKullaniciDepartmanWithSube';
  static const String sayimListeEndpoint = '/api/Procedure/Stok_Sayim_Liste';
  static const String sayimDeleteEndpoint = '/api/StokSayimBarkod/Delete';
  static const String sayimUpdateEndpoint = '/api/StokSayimBarkod/Update';
  static const String sayimKaydetEndpoint =
      '/api/Procedure/Stok_Sayim_Barkod_Kaydet';
  static const String barkodKontrolEndpoint = '/api/Procedure/Stok_Sayim_Liste';
  static const String amberDepartmentsEndpoint = '/api/StokKodlar/GetBySinif';
  static const String subeEndpoint = '/api/MuhasebeKodlar/GetBySinif';
  static const String stokMasterEndpoint = '/api/StokMaster/GetAllOnlyBarcode';
  static const String stokBirimFiyatEndpoint =
      '/api/Procedure/Stok_Birim_Fiyat';
  static const String amberTalepKaydetEndpoint =
      '/api/StokHareket/InsertAmbarVeDepartman';
  static const String malKabulOrderEndpoint = '/api/Sat_Talep/GetBySiparisno';
  static const String malKabulSaveEndpoint = '/api/MalKabul/Insert';
  static const String efaturaIrsaliyeByEttnGelenEndpoint =
      '/api/Irsaliye/GetByETTN_Gelen';
  static const String efaturaFaturaByEttnGelenEndpoint =
      '/api/Fatura/GetByETTN_Gelen';
  static const String hesapPlanByVergiNoEndpoint =
      '/api/HesapPlan/GetAllByVergiNo';
  static const String stokHareketGetByEttnEndpoint =
      '/api/StokHareket/GetByETTN';
  static const String stokHareketDeleteByIdEndpoint =
      '/api/StokHareket/DeleteById';
  static const String stokHareketInsertBarkodEndpoint =
      '/api/StokHareket/InsertBarkod';
  static const String stokHareketByDateEndpoint =
      '/api/StokHareket/GetByDate';
  static const String malKabulByRefnoEndpoint =
      '/api/MalKabul/GetByRefno';
  static const String stokHareketByFisnoEndpoint =
      '/api/StokHareket/GetByFisno';
  static const String stokHareketByFisnoForMalKabulEndpoint =
      '/api/StokHareket/GetByFisnoForMalKabul';

  // Token alma
  static Future<String> getToken(String username, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$tokenEndpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return response.body.replaceAll('"', ''); // String response'u temizle
      } else if (response.statusCode == 401) {
        throw Exception('Kullanıcı adı veya şifre yanlış');
      } else {
        throw Exception('Token alma hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Login sonrası cache - sadece bir kez çekilir
  static LoginResponse? cachedLoginResponse;

  // Token ile login ve database listesi alma
  static Future<LoginResponse> loginByToken(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$loginByTokenEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(jsonData);
        cachedLoginResponse = loginResponse;
        return loginResponse;
      } else {
        throw Exception('Login hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Departman cache - dbId bazında
  static final Map<int, DepartmentResponse> _departmentCache = {};

  // Departmanları getir
  static Future<DepartmentResponse> getDepartments(
    String token,
    int dbId,
  ) async {
    if (_departmentCache.containsKey(dbId)) {
      return _departmentCache[dbId]!;
    }
    try {
      final response = await _client.get(
        Uri.parse('$backApiBaseUrl$departmentsEndpoint?Db_Id=$dbId'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final departmentResponse = DepartmentResponse.fromJson(jsonData);
        _departmentCache[dbId] = departmentResponse;
        return departmentResponse;
      } else {
        throw Exception(
          'Departman listesi alma hatası: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Sayım listesini getir
  static Future<SayimResponse> getSayimListe(
    String token,
    int dbId,
    String tarih,
    String anaDepo,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$sayimListeEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'RaporTip': 4,
          'BaslangicTarih': tarih,
          'BitisTarih': tarih,
          'SayimTarih': tarih,
          'AnaDepo': anaDepo,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return SayimResponse.fromJson(jsonData);
      } else {
        throw Exception('Sayım listesi alma hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Sayım öğesini sil
  static Future<bool> deleteSayimItem(String token, int dbId, int id) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$sayimDeleteEndpoint?Db_Id=$dbId&Id=$id'),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData['isSucceded'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Sayım öğesini güncelle
  static Future<bool> updateSayimItem(
    String token,
    int dbId,
    int id,
    String tarih,
    String departman,
    String stokKod,
    String barkod,
    String birim,
    int miktar,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$sayimUpdateEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'Id': id,
          'Tarih': tarih,
          'Departman': departman,
          'StokKod': stokKod,
          'Barkod': barkod,
          'Birim': birim,
          'Miktar': miktar,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData['isSucceded'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Barkod kontrolü
  static Future<BarkodKontrolResponse> checkBarkod(
    String token,
    int dbId,
    String tarih1,
    String tarih2,
    String barkod,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$barkodKontrolEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'RaporTip': 6,
          'BaslangicTarih': tarih1,
          'BitisTarih': tarih2,
          'Barkod': barkod,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return BarkodKontrolResponse.fromJson(jsonData);
      } else {
        throw Exception('Barkod kontrolü hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Anlık kaydetme
  static Future<bool> saveSayimItem(
    String token,
    int dbId,
    int id,
    String tarih,
    String departman,
    String stokKod,
    String barkod,
    String birim,
    int miktar,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$sayimKaydetEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'Id': id,
          'Tarih': tarih,
          'Departman': departman,
          'StokKod': stokKod,
          'Barkod': barkod,
          'Birim': birim,
          'Miktar': miktar,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData['isSucceded'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Amber Talep için departmanları getir (Anadepo = true olanlar)
  static Future<DepartmentResponse> getAmberDepartments(
    String token,
    int dbId,
    String sinif,
    bool detayli,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$backApiBaseUrl$amberDepartmentsEndpoint?Db_Id=$dbId&sinif=$sinif&detayli=$detayli',
        ),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return DepartmentResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Departman listesi alma hatası: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Şube listesini getir
  static Future<SubeResponse> getSubeler(
    String token,
    int dbId,
    String sinif,
    bool detayli,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$subeEndpoint'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'db_Id': dbId, 'Sinif': sinif, 'detayli': detayli}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return SubeResponse.fromJson(jsonData);
      } else {
        throw Exception('Şube listesi alma hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Tüm stok master listesini getir (sadece barkod)
  static Future<StokMasterResponse> getStokMaster(
    String token,
    int dbId,
    bool detayli,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$backApiBaseUrl$stokMasterEndpoint?Db_Id=$dbId&detayli=$detayli',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return StokMasterResponse.fromJson(jsonData);
      } else {
        throw Exception('Stok listesi alma hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Stok birim fiyat bilgisi getir
  static Future<StokBirimFiyatResponse> getStokBirimFiyat(
    String token,
    int dbId,
    String stokKodu,
    String tarih1,
    String tarih2,
    String anaDepo,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$stokBirimFiyatEndpoint'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'stok_Kodu': stokKodu,
          'tarih1': tarih1,
          'tarih2': tarih2,
          'ana_Depo': anaDepo,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return StokBirimFiyatResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Stok fiyat bilgisi alma hatası: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Amber talep kaydet
  static Future<Map<String, dynamic>> saveAmberTalep(
    String token,
    int dbId,
    String tarih,
    String depo,
    String alanServis,
    String sirketKod,
    List<Map<String, dynamic>> satirlar,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$amberTalepKaydetEndpoint'),
        headers: {
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'Tarih': tarih,
          'Fisno': 0,
          'Depo': depo,
          'Fistipi': 'J',
          'AlanServis': alanServis,
          'Sirketkod': sirketKod,
          'MatbuFisno': 0,
          'Satirlar': satirlar,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData;
      } else {
        throw Exception('Talep kaydetme hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Mal Kabul - Sipariş getir
  static Future<MalKabulOrderResponse> getMalKabulOrder(
    String token,
    int dbId,
    String siparisno,
    bool detayli,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$backApiBaseUrl$malKabulOrderEndpoint?Db_Id=$dbId&siparisno=$siparisno&detayli=$detayli',
        ),
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return MalKabulOrderResponse.fromJson(jsonData);
      } else {
        throw Exception('Sipariş getirme hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // StokHareket - Tarihe göre getir (Mal Kabul Giriş için)
  static Future<List<Map<String, dynamic>>> getStokHareketByDate({
    required String token,
    required int dbId,
    required String tarih,
    required String sirket,
    String fisTip = 'E',
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketByDateEndpoint')
          .replace(queryParameters: {
        'Db_Id': dbId.toString(),
        'tarih': tarih,
        'detay': 'false',
        'sirket': sirket,
        'fisTip': fisTip,
      });
      final response = await _client.get(
        uri,
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final list = json['value'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      } else {
        throw Exception('GetByDate hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // StokHareket - Fiş numarası ile getir (Mal Kabul Giriş)
  static Future<Map<String, dynamic>> getStokHareketByFisno({
    required String token,
    required int dbId,
    required int fisno,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketByFisnoEndpoint')
          .replace(queryParameters: {
        'Db_Id': dbId.toString(),
        'Fisno': fisno.toString(),
      });
      final response = await _client.get(
        uri,
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('GetByFisno hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // StokHareket - Fiş numarası ile MalKabul satırlarını getir
  static Future<List<Map<String, dynamic>>> getStokHareketByFisnoForMalKabul({
    required String token,
    required int dbId,
    required int fisno,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketByFisnoForMalKabulEndpoint')
          .replace(queryParameters: {
        'Db_Id': dbId.toString(),
        'Fisno': fisno.toString(),
      });
      final response = await _client.get(
        uri,
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final list = decoded['value'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      } else {
        throw Exception('GetByFisnoForMalKabul hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // MalKabul - RefNo ile getir
  static Future<List<MalKabulSaveItem>> getMalKabulByRefno({
    required String token,
    required int dbId,
    required int refno,
    String tip = 'S',
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$malKabulByRefnoEndpoint')
          .replace(queryParameters: {
        'Db_Id': dbId.toString(),
        'tip': tip,
        'refno': refno.toString(),
      });
      final response = await _client.get(
        uri,
        headers: {'accept': 'application/json', 'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final list = json['value'] as List<dynamic>? ?? [];
        return list.map((e) => MalKabulSaveItem.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        throw Exception('GetByRefno hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  static Future<EfaturaIrsaliyeResponse> getBelgeByEttnGelen({
    required String token,
    required int efaturaDbId,
    required int sirketId,
    required String ettn,
    required bool detay,
    required bool isFatura,
  }) async {
    try {
      final endpoint =
          isFatura
              ? efaturaFaturaByEttnGelenEndpoint
              : efaturaIrsaliyeByEttnGelenEndpoint;
      final uri = Uri.parse('$efaturaApiBaseUrl$endpoint')
          .replace(
            queryParameters: <String, String>{
              'Db_Id': efaturaDbId.toString(),
              'sirketId': sirketId.toString(),
              'ETTN': ettn,
              'detay': detay.toString(),
            },
          );

      final headers = <String, String>{
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await _client.get(
        uri,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return EfaturaIrsaliyeResponse.fromJson(jsonData);
      } else {
        throw ApiHttpException(
          method: 'GET',
          uri: uri,
          requestHeaders: headers,
          requestBody: null,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } catch (e) {
      if (e is ApiHttpException) rethrow;
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Mal Kabul - Kaydet
  static Future<Map<String, dynamic>> saveMalKabul(
    String token,
    int dbId,
    String refTip,
    String refNo,
    int efatSirket,
    String efatDb,
    List<Map<String, dynamic>> satirlar,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$backApiBaseUrl$malKabulSaveEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'RefTip': refTip,
          'RefNo': refNo,
          'Efat_Sirket': efatSirket,
          'Efat_Db': efatDb,
          'Satirlar': satirlar,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return jsonData;
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ??
              'Mal Kabul kaydetme hatası: ${response.statusCode}',
        );
      } else {
        throw Exception('Mal Kabul kaydetme hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  static Future<String?> getHesapPlanKodByVergiNo({
    required String token,
    required int dbId,
    required String vergino,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$hesapPlanByVergiNoEndpoint').replace(
        queryParameters: <String, String>{
          'Db_Id': dbId.toString(),
          'vergino': vergino,
        },
      );

      final headers = <String, String>{
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await _client.get(
        uri,
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw ApiHttpException(
          method: 'GET',
          uri: uri,
          requestHeaders: headers,
          requestBody: null,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['value'];
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map<String, dynamic>) {
            final kod = first['Kod'] ?? first['kod'];
            return kod?.toString().trim();
          }
        } else if (value is Map<String, dynamic>) {
          final kod = value['Kod'] ?? value['kod'];
          return kod?.toString().trim();
        }
      }

      // Bazı servisler listeyi direkt döndürebiliyor.
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) {
          final kod = first['Kod'] ?? first['kod'];
          return kod?.toString().trim();
        }
      }

      return null;
    } catch (e) {
      if (e is ApiHttpException) rethrow;
      throw Exception('Bağlantı hatası: $e');
    }
  }

  static Future<Map<String, dynamic>> insertStokHareketBarkod({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketInsertBarkodEndpoint');
      final headers = <String, String>{
        'accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic>
            ? decoded
            : <String, dynamic>{'raw': decoded};
      }

      throw ApiHttpException(
        method: 'POST',
        uri: uri,
        requestHeaders: headers,
        requestBody: body,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    } catch (e) {
      if (e is ApiHttpException) rethrow;
      throw Exception('Bağlantı hatası: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getStokHareketByEttn({
    required String token,
    required int dbId,
    required String ettn,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketGetByEttnEndpoint').replace(
        queryParameters: <String, String>{
          'Db_Id': dbId.toString(),
          'ETTN': ettn,
        },
      );

      final headers = <String, String>{
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.get(uri, headers: headers);
      if (response.statusCode != 200) {
        throw ApiHttpException(
          method: 'GET',
          uri: uri,
          requestHeaders: headers,
          requestBody: null,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['value'];
        if (value is List) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
      }
      return const <Map<String, dynamic>>[];
    } catch (e) {
      if (e is ApiHttpException) rethrow;
      throw Exception('Bağlantı hatası: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteStokHareketById({
    required String token,
    required int dbId,
    required int id,
  }) async {
    try {
      final uri = Uri.parse('$backApiBaseUrl$stokHareketDeleteByIdEndpoint').replace(
        queryParameters: <String, String>{
          'Db_Id': dbId.toString(),
          'Id': id.toString(),
        },
      );

      final headers = <String, String>{
        'accept': '*/*',
        'Authorization': 'Bearer $token',
      };

      final response = await _client.delete(uri, headers: headers);
      if (response.statusCode != 200) {
        throw ApiHttpException(
          method: 'DELETE',
          uri: uri,
          requestHeaders: headers,
          requestBody: null,
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'raw': decoded};
    } catch (e) {
      if (e is ApiHttpException) rethrow;
      throw Exception('Bağlantı hatası: $e');
    }
  }
}
