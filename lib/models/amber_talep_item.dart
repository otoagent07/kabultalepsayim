class AmberTalepItem {
  final String stokkod;
  final String stokAd;
  final String birim;
  final String barkod;
  final int miktar;
  final double birimFiyat;
  final double tutar;
  final double kalanMiktar;

  AmberTalepItem({
    required this.stokkod,
    required this.stokAd,
    required this.birim,
    required this.barkod,
    required this.miktar,
    required this.birimFiyat,
    required this.tutar,
    required this.kalanMiktar,
  });

  AmberTalepItem copyWith({
    String? stokkod,
    String? stokAd,
    String? birim,
    String? barkod,
    int? miktar,
    double? birimFiyat,
    double? tutar,
    double? kalanMiktar,
  }) {
    return AmberTalepItem(
      stokkod: stokkod ?? this.stokkod,
      stokAd: stokAd ?? this.stokAd,
      birim: birim ?? this.birim,
      barkod: barkod ?? this.barkod,
      miktar: miktar ?? this.miktar,
      birimFiyat: birimFiyat ?? this.birimFiyat,
      tutar: tutar ?? this.tutar,
      kalanMiktar: kalanMiktar ?? this.kalanMiktar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': 0,
      'Stokkod': stokkod,
      'StokAd': stokAd,
      'Birim': birim,
      'Kdv': 0,
      'Miktar': miktar,
      'Birimfiyat': birimFiyat,
      'Tutar': tutar,
      'Nettutar': tutar,
      'Kdvtutar': 0,
      'Toplam': tutar,
      'Barkod': barkod,
      'Aciklama': 'Mobilden gönderildi',
    };
  }
}
