class StokBarkod {
  final int bId;
  final String bStokkod;
  final String bBarkod;
  final String stokAdi;
  final String birimKod;
  final String birimAd;

  StokBarkod({
    required this.bId,
    required this.bStokkod,
    required this.bBarkod,
    required this.stokAdi,
    required this.birimKod,
    required this.birimAd,
  });

  factory StokBarkod.fromJson(Map<String, dynamic> json) {
    return StokBarkod(
      bId: json['B_Id'] ?? 0,
      bStokkod: json['B_Stokkod'] ?? '',
      bBarkod: json['B_Barkod'] ?? '',
      stokAdi: json['StokAdi'] ?? '',
      birimKod: json['BirimKod'] ?? '',
      birimAd: json['BirimAd'] ?? '',
    );
  }
}
