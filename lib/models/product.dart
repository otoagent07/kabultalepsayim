class Product {
  final String stokad;
  final String stokkod;
  final int kalanmiktar;
  final double fiyat;

  Product({
    required this.stokad,
    required this.stokkod,
    required this.kalanmiktar,
    required this.fiyat,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      stokad: json['stokad'] ?? '',
      stokkod: json['stokkod'] ?? '',
      kalanmiktar: json['kalanmiktar'] ?? 0,
      fiyat: (json['fiyat'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stokad': stokad,
      'stokkod': stokkod,
      'kalanmiktar': kalanmiktar,
      'fiyat': fiyat,
    };
  }
}
