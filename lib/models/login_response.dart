import 'api_user.dart';
import 'api_company.dart';
import 'api_hotel.dart';
import 'api_database.dart';

class LoginResponse {
  final ApiUser user;
  final ApiCompany sirket;
  final List<ApiHotel> hotels;
  final List<ApiDatabase> databases;
  final dynamic backYetki;
  final dynamic backYetkiDetay;
  final dynamic frontYetki;
  final dynamic genelYetki;
  final dynamic isTakipYetki;
  final dynamic eFaturaYetki;

  LoginResponse({
    required this.user,
    required this.sirket,
    required this.hotels,
    required this.databases,
    this.backYetki,
    this.backYetkiDetay,
    this.frontYetki,
    this.genelYetki,
    this.isTakipYetki,
    this.eFaturaYetki,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      user: ApiUser.fromJson(json['user'] ?? {}),
      sirket: ApiCompany.fromJson(json['sirket'] ?? {}),
      hotels: (json['hotels'] as List<dynamic>?)
          ?.map((hotel) => ApiHotel.fromJson(hotel))
          .toList() ?? [],
      databases: (json['databases'] as List<dynamic>?)
          ?.map((database) => ApiDatabase.fromJson(database))
          .toList() ?? [],
      backYetki: json['backYetki'],
      backYetkiDetay: json['backYetkiDetay'],
      frontYetki: json['frontYetki'],
      genelYetki: json['genelYetki'],
      isTakipYetki: json['isTakipYetki'],
      eFaturaYetki: json['eFaturaYetki'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'sirket': sirket.toJson(),
      'hotels': hotels.map((hotel) => hotel.toJson()).toList(),
      'databases': databases.map((database) => database.toJson()).toList(),
      'backYetki': backYetki,
      'backYetkiDetay': backYetkiDetay,
      'frontYetki': frontYetki,
      'genelYetki': genelYetki,
      'isTakipYetki': isTakipYetki,
      'eFaturaYetki': eFaturaYetki,
    };
  }
}
