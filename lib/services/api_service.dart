import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_response.dart';

class ApiService {
  static const String baseUrl = 'https://service.rmosweb.com';
  static const String tokenEndpoint = '/security/createToken';
  static const String loginByTokenEndpoint = '/api/Users/LoginByToken';

  // Token alma
  static Future<String> getToken(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tokenEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userName': username,
          'password': password,
        }),
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
}
