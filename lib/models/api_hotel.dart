class ApiHotel {
  final int fldOtelID;
  final String? fldOtelKodu;
  final String fldOtelAdi;
  final int? fldYildiz;
  final int? fldTesisTipiID;
  final int? fldKonaklamaTipiID;
  final int? fldUlkeID;
  final int? fldSehirID;
  final int? fldBolgeID;
  final String? fldAdres;
  final String? fldFax;
  final String? fldTel;
  final String? fldEPosta;
  final double? fldLat;
  final double? fldLong;
  final String? fldAciklama;
  final int? fldGaleriID;
  final String? fldAnaResim;
  final String? fldOnbServer;
  final String? fldOnbUser;
  final String? fldOnbPass;
  final String? fldOnbDatabase;
  final int fldSirketID;
  final String fldOtelGuid;

  ApiHotel({
    required this.fldOtelID,
    this.fldOtelKodu,
    required this.fldOtelAdi,
    this.fldYildiz,
    this.fldTesisTipiID,
    this.fldKonaklamaTipiID,
    this.fldUlkeID,
    this.fldSehirID,
    this.fldBolgeID,
    this.fldAdres,
    this.fldFax,
    this.fldTel,
    this.fldEPosta,
    this.fldLat,
    this.fldLong,
    this.fldAciklama,
    this.fldGaleriID,
    this.fldAnaResim,
    this.fldOnbServer,
    this.fldOnbUser,
    this.fldOnbPass,
    this.fldOnbDatabase,
    required this.fldSirketID,
    required this.fldOtelGuid,
  });

  factory ApiHotel.fromJson(Map<String, dynamic> json) {
    return ApiHotel(
      fldOtelID: json['fldOtelID'] ?? 0,
      fldOtelKodu: json['fldOtelKodu'],
      fldOtelAdi: json['fldOtelAdi'] ?? '',
      fldYildiz: json['fldYildiz'],
      fldTesisTipiID: json['fldTesisTipiID'],
      fldKonaklamaTipiID: json['fldKonaklamaTipiID'],
      fldUlkeID: json['fldUlkeID'],
      fldSehirID: json['fldSehirID'],
      fldBolgeID: json['fldBolgeID'],
      fldAdres: json['fldAdres'],
      fldFax: json['fldFax'],
      fldTel: json['fldTel'],
      fldEPosta: json['fldEPosta'],
      fldLat: json['fldLat']?.toDouble(),
      fldLong: json['fldLong']?.toDouble(),
      fldAciklama: json['fldAciklama'],
      fldGaleriID: json['fldGaleriID'],
      fldAnaResim: json['fldAnaResim'],
      fldOnbServer: json['fldOnbServer'],
      fldOnbUser: json['fldOnbUser'],
      fldOnbPass: json['fldOnbPass'],
      fldOnbDatabase: json['fldOnbDatabase'],
      fldSirketID: json['fldSirketID'] ?? 0,
      fldOtelGuid: json['fldOtelGuid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fldOtelID': fldOtelID,
      'fldOtelKodu': fldOtelKodu,
      'fldOtelAdi': fldOtelAdi,
      'fldYildiz': fldYildiz,
      'fldTesisTipiID': fldTesisTipiID,
      'fldKonaklamaTipiID': fldKonaklamaTipiID,
      'fldUlkeID': fldUlkeID,
      'fldSehirID': fldSehirID,
      'fldBolgeID': fldBolgeID,
      'fldAdres': fldAdres,
      'fldFax': fldFax,
      'fldTel': fldTel,
      'fldEPosta': fldEPosta,
      'fldLat': fldLat,
      'fldLong': fldLong,
      'fldAciklama': fldAciklama,
      'fldGaleriID': fldGaleriID,
      'fldAnaResim': fldAnaResim,
      'fldOnbServer': fldOnbServer,
      'fldOnbUser': fldOnbUser,
      'fldOnbPass': fldOnbPass,
      'fldOnbDatabase': fldOnbDatabase,
      'fldSirketID': fldSirketID,
      'fldOtelGuid': fldOtelGuid,
    };
  }
}
