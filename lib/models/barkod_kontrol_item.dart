class BarkodKontrolItem {
  final int id;
  final String barkod;
  final String masterGenelKod;
  final String masterAd;
  final String masterAltbirim;

  BarkodKontrolItem({
    required this.id,
    required this.barkod,
    required this.masterGenelKod,
    required this.masterAd,
    required this.masterAltbirim,
  });

  factory BarkodKontrolItem.fromJson(Map<String, dynamic> json) {
    return BarkodKontrolItem(
      id: json['Id'] ?? 0,
      barkod: json['Barkod'] ?? '',
      masterGenelKod: json['Master_GenelKod'] ?? '',
      masterAd: json['Master_Ad'] ?? '',
      masterAltbirim: json['Master_Altbirim'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Barkod': barkod,
      'Master_GenelKod': masterGenelKod,
      'Master_Ad': masterAd,
      'Master_Altbirim': masterAltbirim,
    };
  }
}
