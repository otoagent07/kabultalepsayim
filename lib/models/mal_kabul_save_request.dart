import 'mal_kabul_save_item.dart';

class MalKabulSaveRequest {
  final int dbId;
  final String tarih;
  final String refTip;
  final String refNo;
  final int efatSirket;
  final String efatDb;
  final List<MalKabulSaveItem> satirlar;

  MalKabulSaveRequest({
    required this.dbId,
    required this.tarih,
    required this.refTip,
    required this.refNo,
    required this.efatSirket,
    required this.efatDb,
    required this.satirlar,
  });

  factory MalKabulSaveRequest.fromJson(Map<String, dynamic> json) {
    return MalKabulSaveRequest(
      dbId: json['db_Id'] ?? 0,
      tarih: json['Tarih'] ?? '',
      refTip: json['RefTip'] ?? '',
      refNo: json['RefNo'] ?? '',
      efatSirket: json['Efat_Sirket'] ?? 0,
      efatDb: json['Efat_Db'] ?? '',
      satirlar:
          (json['Satirlar'] as List<dynamic>?)
              ?.map((item) => MalKabulSaveItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'db_Id': dbId,
      'Tarih': tarih,
      'RefTip': refTip,
      'RefNo': refNo,
      'Efat_Sirket': efatSirket,
      'Efat_Db': efatDb,
      'Satirlar': satirlar.map((item) => item.toJson()).toList(),
    };
  }
}
