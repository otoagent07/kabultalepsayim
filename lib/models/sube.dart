class Sube {
  final int id;
  final String kod;
  final String ad;
  final String sinif;
  final String onbWebId;
  final int dbId;

  Sube({
    required this.id,
    required this.kod,
    required this.ad,
    required this.sinif,
    required this.onbWebId,
    required this.dbId,
  });

  factory Sube.fromJson(Map<String, dynamic> json) {
    return Sube(
      id: json['Id'] ?? 0,
      kod: json['Kod'] ?? '',
      ad: json['Ad'] ?? '',
      sinif: json['Sinif'] ?? '',
      onbWebId: json['OnbWebId'] ?? '',
      dbId: json['db_Id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Kod': kod,
      'Ad': ad,
      'Sinif': sinif,
      'OnbWebId': onbWebId,
      'db_Id': dbId,
    };
  }
}

