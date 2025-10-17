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
    required this.dbId,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
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
      'db_Id': dbId,
    };
  }
}
