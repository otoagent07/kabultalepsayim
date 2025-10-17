class StokBirimFiyat {
  final String stokKod;
  final String stokAd;
  final String birim;
  final double devirMiktar;
  final double devirTutar;
  final double girisMiktar;
  final double girisTutar;
  final double toplamMiktar;
  final double toplamTutar;
  final double cikisMiktar;
  final double cikisTutar;
  final double kalanMiktar;
  final double kalanTutar;
  final double birimFiyat;
  final double birimFiyat2;
  final double birimFiyat3;
  final double sonAlimFiyat;

  StokBirimFiyat({
    required this.stokKod,
    required this.stokAd,
    required this.birim,
    required this.devirMiktar,
    required this.devirTutar,
    required this.girisMiktar,
    required this.girisTutar,
    required this.toplamMiktar,
    required this.toplamTutar,
    required this.cikisMiktar,
    required this.cikisTutar,
    required this.kalanMiktar,
    required this.kalanTutar,
    required this.birimFiyat,
    required this.birimFiyat2,
    required this.birimFiyat3,
    required this.sonAlimFiyat,
  });

  factory StokBirimFiyat.fromJson(Map<String, dynamic> json) {
    return StokBirimFiyat(
      stokKod: json['stok_Kod'] ?? '',
      stokAd: json['stok_Ad'] ?? '',
      birim: json['birim'] ?? '',
      devirMiktar: (json['devir_Miktar'] ?? 0).toDouble(),
      devirTutar: (json['devir_Tutar'] ?? 0).toDouble(),
      girisMiktar: (json['giris_Miktar'] ?? 0).toDouble(),
      girisTutar: (json['giris_Tutar'] ?? 0).toDouble(),
      toplamMiktar: (json['toplam_Miktar'] ?? 0).toDouble(),
      toplamTutar: (json['toplam_Tutar'] ?? 0).toDouble(),
      cikisMiktar: (json['cikis_Miktar'] ?? 0).toDouble(),
      cikisTutar: (json['cikis_Tutar'] ?? 0).toDouble(),
      kalanMiktar: (json['kalan_Miktar'] ?? 0).toDouble(),
      kalanTutar: (json['kalan_Tutar'] ?? 0).toDouble(),
      birimFiyat: (json['birim_fiyat'] ?? 0).toDouble(),
      birimFiyat2: (json['birim_fiyat2'] ?? 0).toDouble(),
      birimFiyat3: (json['birim_fiyat3'] ?? 0).toDouble(),
      sonAlimFiyat: (json['sonAlimFiyat'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stok_Kod': stokKod,
      'stok_Ad': stokAd,
      'birim': birim,
      'devir_Miktar': devirMiktar,
      'devir_Tutar': devirTutar,
      'giris_Miktar': girisMiktar,
      'giris_Tutar': girisTutar,
      'toplam_Miktar': toplamMiktar,
      'toplam_Tutar': toplamTutar,
      'cikis_Miktar': cikisMiktar,
      'cikis_Tutar': cikisTutar,
      'kalan_Miktar': kalanMiktar,
      'kalan_Tutar': kalanTutar,
      'birim_fiyat': birimFiyat,
      'birim_fiyat2': birimFiyat2,
      'birim_fiyat3': birimFiyat3,
      'sonAlimFiyat': sonAlimFiyat,
    };
  }
}
