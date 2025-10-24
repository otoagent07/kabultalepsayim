class MalKabulSaveItem {
  final int id;
  final int efatId;
  final int sira;
  final String urunAdi;
  final String firma;
  final double miktar;
  final String birim;
  final String partiNo;
  final String sonKullanimTarih;
  final double urunSicaklik;
  final double aracSicaklik;
  final bool urunOnay;
  final bool aracOnay;
  final bool pandemiOnay;
  final bool hammaddeOnay;
  final bool dezenfeksiyonOnay;
  final bool personelOnay;

  MalKabulSaveItem({
    required this.id,
    required this.efatId,
    required this.sira,
    required this.urunAdi,
    required this.firma,
    required this.miktar,
    required this.birim,
    required this.partiNo,
    required this.sonKullanimTarih,
    required this.urunSicaklik,
    required this.aracSicaklik,
    required this.urunOnay,
    required this.aracOnay,
    required this.pandemiOnay,
    required this.hammaddeOnay,
    required this.dezenfeksiyonOnay,
    required this.personelOnay,
  });

  factory MalKabulSaveItem.fromJson(Map<String, dynamic> json) {
    return MalKabulSaveItem(
      id: json['Id'] ?? 0,
      efatId: json['EfatId'] ?? 0,
      sira: json['Sira'] ?? 0,
      urunAdi: json['UrunAdi'] ?? '',
      firma: json['Firma'] ?? '',
      miktar: (json['Miktar'] ?? 0.0).toDouble(),
      birim: json['Birim'] ?? '',
      partiNo: json['PartiNo'] ?? '',
      sonKullanimTarih: json['SonKullanimTarih'] ?? '',
      urunSicaklik: (json['UrunSicaklik'] ?? 0.0).toDouble(),
      aracSicaklik: (json['AracSicaklik'] ?? 0.0).toDouble(),
      urunOnay: json['UrunOnay'] ?? false,
      aracOnay: json['AracOnay'] ?? false,
      pandemiOnay: json['PandemiOnay'] ?? false,
      hammaddeOnay: json['HammaddeOnay'] ?? false,
      dezenfeksiyonOnay: json['DezenfeksiyonOnay'] ?? false,
      personelOnay: json['PersonelOnay'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'EfatId': efatId,
      'Sira': sira,
      'UrunAdi': urunAdi,
      'Firma': firma,
      'Miktar': miktar,
      'Birim': birim,
      'PartiNo': partiNo,
      'SonKullanimTarih': sonKullanimTarih,
      'UrunSicaklik': urunSicaklik,
      'AracSicaklik': aracSicaklik,
      'UrunOnay': urunOnay,
      'AracOnay': aracOnay,
      'PandemiOnay': pandemiOnay,
      'HammaddeOnay': hammaddeOnay,
      'DezenfeksiyonOnay': dezenfeksiyonOnay,
      'PersonelOnay': personelOnay,
    };
  }
}
