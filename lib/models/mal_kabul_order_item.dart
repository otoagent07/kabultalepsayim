class MalKabulOrderItem {
  final int id;
  final String tarih;
  final int fisno;
  final String departman;
  final String altDepartman;
  final String stokkod;
  final String stokAd;
  final String birim;
  final double miktar;
  final double onayMiktar;
  final double stokMiktar;
  final double sonalim;
  final double tahmini;
  final double ortalama;
  final String tipi;
  final String seciliSatici;
  final double seciliFiyat;
  final double seciliToplam;
  final int saticino;
  final int siparisno;
  final bool siparisTr;
  final bool anlasmadan;
  final String depo;
  final String sonalimcari;
  final String? sonalimTarih;
  final double sonalimMiktar;
  final bool barkodlandi;
  final double depStokMiktar;
  final int tesellumId;
  final double tesellumMiktar;
  final bool tesellumMevcut;
  final String? tesellumBarkod;

  MalKabulOrderItem({
    required this.id,
    required this.tarih,
    required this.fisno,
    required this.departman,
    required this.altDepartman,
    required this.stokkod,
    required this.stokAd,
    required this.birim,
    required this.miktar,
    required this.onayMiktar,
    required this.stokMiktar,
    required this.sonalim,
    required this.tahmini,
    required this.ortalama,
    required this.tipi,
    required this.seciliSatici,
    required this.seciliFiyat,
    required this.seciliToplam,
    required this.saticino,
    required this.siparisno,
    required this.siparisTr,
    required this.anlasmadan,
    required this.depo,
    required this.sonalimcari,
    this.sonalimTarih,
    required this.sonalimMiktar,
    required this.barkodlandi,
    required this.depStokMiktar,
    required this.tesellumId,
    required this.tesellumMiktar,
    required this.tesellumMevcut,
    this.tesellumBarkod,
  });

  factory MalKabulOrderItem.fromJson(Map<String, dynamic> json) {
    return MalKabulOrderItem(
      id: json['Id'] ?? 0,
      tarih: json['Tarih'] ?? '',
      fisno: json['Fisno'] ?? 0,
      departman: json['Departman'] ?? '',
      altDepartman: json['AltDepartman'] ?? '',
      stokkod: json['Stokkod'] ?? '',
      stokAd: json['StokAd'] ?? '',
      birim: json['Birim'] ?? '',
      miktar: (json['Miktar'] ?? 0.0).toDouble(),
      onayMiktar: (json['OnayMiktar'] ?? 0.0).toDouble(),
      stokMiktar: (json['StokMiktar'] ?? 0.0).toDouble(),
      sonalim: (json['Sonalim'] ?? 0.0).toDouble(),
      tahmini: (json['Tahmini'] ?? 0.0).toDouble(),
      ortalama: (json['Ortalama'] ?? 0.0).toDouble(),
      tipi: json['Tipi'] ?? '',
      seciliSatici: json['SeciliSatici'] ?? '',
      seciliFiyat: (json['SeciliFiyat'] ?? 0.0).toDouble(),
      seciliToplam: (json['SeciliToplam'] ?? 0.0).toDouble(),
      saticino: json['Saticino'] ?? 0,
      siparisno: json['Siparisno'] ?? 0,
      siparisTr: json['SiparisTr'] ?? false,
      anlasmadan: json['Anlasmadan'] ?? false,
      depo: json['Depo'] ?? '',
      sonalimcari: json['Sonalimcari'] ?? '',
      sonalimTarih: json['SonalimTarih'],
      sonalimMiktar: (json['SonalimMiktar'] ?? 0.0).toDouble(),
      barkodlandi: json['Barkodlandi'] ?? false,
      depStokMiktar: (json['DepStokMiktar'] ?? 0.0).toDouble(),
      tesellumId: json['Tesellum_Id'] ?? 0,
      tesellumMiktar: (json['Tesellum_Miktar'] ?? 0.0).toDouble(),
      tesellumMevcut: json['Tesellum_Mevcut'] ?? false,
      tesellumBarkod: json['Tesellum_Barkod']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Tarih': tarih,
      'Fisno': fisno,
      'Departman': departman,
      'AltDepartman': altDepartman,
      'Stokkod': stokkod,
      'StokAd': stokAd,
      'Birim': birim,
      'Miktar': miktar,
      'OnayMiktar': onayMiktar,
      'StokMiktar': stokMiktar,
      'Sonalim': sonalim,
      'Tahmini': tahmini,
      'Ortalama': ortalama,
      'Tipi': tipi,
      'SeciliSatici': seciliSatici,
      'SeciliFiyat': seciliFiyat,
      'SeciliToplam': seciliToplam,
      'Saticino': saticino,
      'Siparisno': siparisno,
      'SiparisTr': siparisTr,
      'Anlasmadan': anlasmadan,
      'Depo': depo,
      'Sonalimcari': sonalimcari,
      'SonalimTarih': sonalimTarih,
      'SonalimMiktar': sonalimMiktar,
      'Barkodlandi': barkodlandi,
      'DepStokMiktar': depStokMiktar,
      'Tesellum_Id': tesellumId,
      'Tesellum_Miktar': tesellumMiktar,
      'Tesellum_Mevcut': tesellumMevcut,
      'Tesellum_Barkod': tesellumBarkod,
    };
  }
}
