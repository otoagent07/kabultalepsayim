class StokMaster {
  final int id;
  final String anagrup;
  final String aragrup;
  final String altgrup;
  final String kod;
  final String genelKod;
  final String ad;
  final String anabirim;
  final String altbirim;
  final String barkod1;

  StokMaster({
    required this.id,
    required this.anagrup,
    required this.aragrup,
    required this.altgrup,
    required this.kod,
    required this.genelKod,
    required this.ad,
    required this.anabirim,
    required this.altbirim,
    required this.barkod1,
  });

  factory StokMaster.fromJson(Map<String, dynamic> json) {
    return StokMaster(
      id: json['Id'] ?? 0,
      anagrup: json['Anagrup'] ?? '',
      aragrup: json['Aragrup'] ?? '',
      altgrup: json['Altgrup'] ?? '',
      kod: json['Kod'] ?? '',
      genelKod: json['GenelKod'] ?? '',
      ad: json['Ad'] ?? '',
      anabirim: json['Anabirim'] ?? '',
      altbirim: json['Altbirim'] ?? '',
      barkod1: json['Barkod1'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Anagrup': anagrup,
      'Aragrup': aragrup,
      'Altgrup': altgrup,
      'Kod': kod,
      'GenelKod': genelKod,
      'Ad': ad,
      'Anabirim': anabirim,
      'Altbirim': altbirim,
      'Barkod1': barkod1,
    };
  }
}
