class Department {
  final int id;
  final String kod;
  final String ad;
  final String sinif;
  final String? anaGrup;
  final String? araGrup;
  final bool anadepo;
  final String sube;
  final double carpan;
  final bool satis;
  final String? eFatDb;
  final int? eFatSirketId;
  final int dbId;

  Department({
    required this.id,
    required this.kod,
    required this.ad,
    required this.sinif,
    this.anaGrup,
    this.araGrup,
    required this.anadepo,
    required this.sube,
    required this.carpan,
    required this.satis,
    this.eFatDb,
    this.eFatSirketId,
    required this.dbId,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    final dynamic efatSirketRaw =
        json['EFat_SirketID'] ?? json['EFat_SirketId'] ?? json['Efat_SirketID'];
    return Department(
      id: json['Id'] ?? 0,
      kod: json['Kod'] ?? '',
      ad: json['Ad'] ?? '',
      sinif: json['Sinif'] ?? '',
      anaGrup: json['AnaGrup'],
      araGrup: json['AraGrup'],
      anadepo: json['Anadepo'] ?? false,
      sube: json['Sube'] ?? '',
      carpan: (json['Carpan'] ?? 0.0).toDouble(),
      satis: json['Satis'] ?? false,
      eFatDb: json['EFat_Db'],
      eFatSirketId: efatSirketRaw is int ? efatSirketRaw : int.tryParse('$efatSirketRaw'),
      dbId: json['db_Id'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Kod': kod,
      'Ad': ad,
      'Sinif': sinif,
      'AnaGrup': anaGrup,
      'AraGrup': araGrup,
      'Anadepo': anadepo,
      'Sube': sube,
      'Carpan': carpan,
      'Satis': satis,
      'EFat_Db': eFatDb,
      'EFat_SirketID': eFatSirketId,
      'db_Id': dbId,
    };
  }
}
