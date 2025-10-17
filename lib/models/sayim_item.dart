class SayimItem {
  final int sayimId;
  final String sayimTarih;
  final String sayimDepartman;
  final String sayimStokkod;
  final String sayimBarkod;
  final String sayimAltbirim;
  final double sayimMiktar;
  final String sayimTipi;
  final String depAd;
  final String? masterAd;
  final double sayimOrtalama;
  final double sayimTutar;

  SayimItem({
    required this.sayimId,
    required this.sayimTarih,
    required this.sayimDepartman,
    required this.sayimStokkod,
    required this.sayimBarkod,
    required this.sayimAltbirim,
    required this.sayimMiktar,
    required this.sayimTipi,
    required this.depAd,
    this.masterAd,
    required this.sayimOrtalama,
    required this.sayimTutar,
  });

  factory SayimItem.fromJson(Map<String, dynamic> json) {
    return SayimItem(
      sayimId: json['Sayim_Id'] ?? 0,
      sayimTarih: json['Sayim_Tarih'] ?? '',
      sayimDepartman: json['Sayim_Departman'] ?? '',
      sayimStokkod: json['Sayim_Stokkod'] ?? '',
      sayimBarkod: json['Sayim_Barkod'] ?? '',
      sayimAltbirim: json['Sayim_Altbirim'] ?? '',
      sayimMiktar: (json['Sayim_Miktar'] ?? 0.0).toDouble(),
      sayimTipi: json['Sayim_Tipi'] ?? '',
      depAd: json['Dep_Ad'] ?? '',
      masterAd: json['Master_Ad'],
      sayimOrtalama: (json['Sayim_Ortalama'] ?? 0.0).toDouble(),
      sayimTutar: (json['Sayim_Tutar'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Sayim_Id': sayimId,
      'Sayim_Tarih': sayimTarih,
      'Sayim_Departman': sayimDepartman,
      'Sayim_Stokkod': sayimStokkod,
      'Sayim_Barkod': sayimBarkod,
      'Sayim_Altbirim': sayimAltbirim,
      'Sayim_Miktar': sayimMiktar,
      'Sayim_Tipi': sayimTipi,
      'Dep_Ad': depAd,
      'Master_Ad': masterAd,
      'Sayim_Ortalama': sayimOrtalama,
      'Sayim_Tutar': sayimTutar,
    };
  }
}
