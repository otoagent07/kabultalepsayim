class RequestItem {
  final String id;
  final String stokad;
  final String stokkod;
  final int kalanmiktar;
  final double fiyat;
  final int talepedilenMiktar;
  final double toplamTutar;
  final DateTime date;
  final String department;

  RequestItem({
    required this.id,
    required this.stokad,
    required this.stokkod,
    required this.kalanmiktar,
    required this.fiyat,
    required this.talepedilenMiktar,
    required this.toplamTutar,
    required this.date,
    required this.department,
  });

  RequestItem copyWith({
    String? id,
    String? stokad,
    String? stokkod,
    int? kalanmiktar,
    double? fiyat,
    int? talepedilenMiktar,
    double? toplamTutar,
    DateTime? date,
    String? department,
  }) {
    return RequestItem(
      id: id ?? this.id,
      stokad: stokad ?? this.stokad,
      stokkod: stokkod ?? this.stokkod,
      kalanmiktar: kalanmiktar ?? this.kalanmiktar,
      fiyat: fiyat ?? this.fiyat,
      talepedilenMiktar: talepedilenMiktar ?? this.talepedilenMiktar,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      date: date ?? this.date,
      department: department ?? this.department,
    );
  }
}
