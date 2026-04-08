import 'mal_kabul_order_item.dart';

class EfaturaIrsaliyeResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final EfaturaIrsaliyeValue? value;

  EfaturaIrsaliyeResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory EfaturaIrsaliyeResponse.fromJson(Map<String, dynamic> json) {
    return EfaturaIrsaliyeResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? const [],
      value:
          json['value'] is Map<String, dynamic>
              ? EfaturaIrsaliyeValue.fromJson(
                json['value'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  List<MalKabulOrderItem> toMalKabulOrderItems() {
    final lines = value?.lines ?? const <EfaturaIrsaliyeLine>[];
    return lines.map((l) {
      final stokKodRaw = (l.stokKod ?? '').trim();
      final stokKod = stokKodRaw.isNotEmpty ? stokKodRaw : l.id.toString();
      return MalKabulOrderItem(
        id: l.id,
        tarih: value?.tarihi ?? '',
        fisno: 0,
        departman: '',
        altDepartman: '',
        stokkod: stokKod,
        stokAd: (l.hizmet ?? '').trim(),
        birim: (l.birim ?? '').trim(),
        miktar: l.miktar ?? 0,
        onayMiktar: 0,
        stokMiktar: 0,
        sonalim: 0,
        tahmini: 0,
        ortalama: 0,
        tipi: '',
        seciliSatici: '',
        seciliFiyat: l.fiyat ?? 0,
        seciliToplam: l.tutar ?? 0,
        saticino: 0,
        siparisno: 0,
        siparisTr: false,
        anlasmadan: false,
        depo: '',
        sonalimcari: '',
        sonalimTarih: null,
        sonalimMiktar: 0,
        barkodlandi: false,
        depStokMiktar: 0,
      );
    }).toList();
  }
}

class EfaturaIrsaliyeValue {
  final int? id;
  final String? tarihi;
  final String? vergino;
  final String? eirsaliyeENo;
  final String? senaryo;
  final List<EfaturaIrsaliyeLine> lines;

  EfaturaIrsaliyeValue({
    this.id,
    this.tarihi,
    this.vergino,
    this.eirsaliyeENo,
    this.senaryo,
    required this.lines,
  });

  factory EfaturaIrsaliyeValue.fromJson(Map<String, dynamic> json) {
    final rawLines = json['Satırlar'] ?? json['Satirlar'] ?? json['satirlar'];
    final list =
        rawLines is List
            ? rawLines
                .whereType<Map<String, dynamic>>()
                .map(EfaturaIrsaliyeLine.fromJson)
                .toList()
            : <EfaturaIrsaliyeLine>[];
    return EfaturaIrsaliyeValue(
      id: json['Id'],
      tarihi: json['Tarihi'],
      vergino:
          (json['Vergino'] ?? json['VergiNo'] ?? json['Vkn'] ?? json['VKN'])
              ?.toString()
              .trim(),
      eirsaliyeENo:
          (json['Eirsaliye_ENo'] ??
                  json['EirsaliyeENo'] ??
                  json['EirsaliyeNo'] ??
                  json['Eirsaliye_No'])
              ?.toString()
              .trim(),
      senaryo: (json['Senaryo'] ?? json['senaryo'])?.toString().trim(),
      lines: list,
    );
  }
}

class EfaturaIrsaliyeLine {
  final int id;
  final String? stokKod;
  final String? hizmet;
  final double? miktar;
  final String? birim;
  final double? fiyat;
  final double? tutar;

  EfaturaIrsaliyeLine({
    required this.id,
    this.stokKod,
    this.hizmet,
    this.miktar,
    this.birim,
    this.fiyat,
    this.tutar,
  });

  factory EfaturaIrsaliyeLine.fromJson(Map<String, dynamic> json) {
    return EfaturaIrsaliyeLine(
      id: json['Id'] ?? 0,
      stokKod: json['StokKod'],
      hizmet: json['Hizmet'],
      miktar: (json['Miktar'] == null) ? null : (json['Miktar'] as num).toDouble(),
      birim: json['Birim'],
      fiyat: (json['Fiyat'] == null) ? null : (json['Fiyat'] as num).toDouble(),
      tutar: (json['Tutar'] == null) ? null : (json['Tutar'] as num).toDouble(),
    );
  }
}

