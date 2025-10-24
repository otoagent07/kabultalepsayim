import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_response.dart';
import '../models/department_response.dart';
import '../models/sayim_response.dart';
import '../models/barkod_kontrol_response.dart';
import '../models/sube_response.dart';
import '../models/stok_master_response.dart';
import '../models/stok_birim_fiyat_response.dart';
import '../models/mal_kabul_order_response.dart';
import '../models/mal_kabul_save_response.dart';

class ApiService {
  static const String baseUrl = 'https://service.rmosweb.com';
  static const String backApiBaseUrl = 'https://backapi.rmosweb.com';
  static const String tokenEndpoint = '/security/createToken';
  static const String loginByTokenEndpoint = '/api/Users/LoginByToken';
  static const String departmentsEndpoint =
      '/api/StokKodlar/GetKullaniciDepartman';
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
  static const String malKabulOrderEndpoint = '/api/SatTalep/GetBySiparisno';
  static const String malKabulSaveEndpoint = '/api/MalKabul/Insert';

  // Token alma
  static Future<String> getToken(String username, String password) async {
    try {
      final response = await http.post(
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

  // Token ile login ve database listesi alma
  static Future<LoginResponse> loginByToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$loginByTokenEndpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return LoginResponse.fromJson(jsonData);
      } else {
        throw Exception('Login hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // Departmanları getir
  static Future<DepartmentResponse> getDepartments(
    String token,
    int dbId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$backApiBaseUrl$departmentsEndpoint?Db_Id=$dbId'),
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

  // Sayım listesini getir
  static Future<SayimResponse> getSayimListe(
    String token,
    int dbId,
    String tarih,
    String anaDepo,
  ) async {
    try {
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.get(
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
      final response = await http.post(
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
      final response = await http.get(
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
      final response = await http.post(
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
      final response = await http.post(
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
      final response = await http.get(
        Uri.parse(
          '$backApiBaseUrl$malKabulOrderEndpoint?Db_Id=$dbId&siparisno=$siparisno&detayli=$detayli',
        ),
        headers: {'accept': '*/*', 'Authorization': 'Bearer $token'},
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

  // Mal Kabul - Kaydet
  static Future<MalKabulSaveResponse> saveMalKabul(
    String token,
    int dbId,
    String tarih,
    String refTip,
    String refNo,
    int efatSirket,
    String efatDb,
    List<Map<String, dynamic>> satirlar,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$backApiBaseUrl$malKabulSaveEndpoint'),
        headers: {
          'accept': '*/*',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'db_Id': dbId,
          'Tarih': tarih,
          'RefTip': refTip,
          'RefNo': refNo,
          'Efat_Sirket': efatSirket,
          'Efat_Db': efatDb,
          'Satirlar': satirlar,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        return MalKabulSaveResponse.fromJson(jsonData);
      } else {
        throw Exception('Mal Kabul kaydetme hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }
}
