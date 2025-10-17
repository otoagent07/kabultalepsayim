class ApiCompany {
  final int fldSirketID;
  final String fldSirketAdi;
  final String? fldSirketAdres;
  final String? fldSirketIlce;
  final String? fldSirketSehir;
  final String? fldOteller;
  final String? fldDbServer;
  final String? fldDbUser;
  final String? fldDbPass;
  final String? fldDbDatabase;
  final String fldGuid;

  ApiCompany({
    required this.fldSirketID,
    required this.fldSirketAdi,
    this.fldSirketAdres,
    this.fldSirketIlce,
    this.fldSirketSehir,
    this.fldOteller,
    this.fldDbServer,
    this.fldDbUser,
    this.fldDbPass,
    this.fldDbDatabase,
    required this.fldGuid,
  });

  factory ApiCompany.fromJson(Map<String, dynamic> json) {
    return ApiCompany(
      fldSirketID: json['fldSirketID'] ?? 0,
      fldSirketAdi: json['fldSirketAdi'] ?? '',
      fldSirketAdres: json['fldSirketAdres'],
      fldSirketIlce: json['fldSirketIlce'],
      fldSirketSehir: json['fldSirketSehir'],
      fldOteller: json['fldOteller'],
      fldDbServer: json['fldDbServer'],
      fldDbUser: json['fldDbUser'],
      fldDbPass: json['fldDbPass'],
      fldDbDatabase: json['fldDbDatabase'],
      fldGuid: json['fldGuid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fldSirketID': fldSirketID,
      'fldSirketAdi': fldSirketAdi,
      'fldSirketAdres': fldSirketAdres,
      'fldSirketIlce': fldSirketIlce,
      'fldSirketSehir': fldSirketSehir,
      'fldOteller': fldOteller,
      'fldDbServer': fldDbServer,
      'fldDbUser': fldDbUser,
      'fldDbPass': fldDbPass,
      'fldDbDatabase': fldDbDatabase,
      'fldGuid': fldGuid,
    };
  }
}
