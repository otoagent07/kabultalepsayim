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
    return lines.map<MalKabulOrderItem>((l) {
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
        tesellumId: 0,
        tesellumMiktar: 0,
        tesellumMevcut: false,
        tesellumBarkod: null,
      );
    }).toList();
  }
}

class EfaturaIrsaliyeValue {
  final int? id;
  final String? tarihi;
  final String? ettn;
  final String? entegreEttn;
  final String? vergino;
  final String? efaturaNo;
  final String? eirsaliyeENo;
  final String? senaryo;
  final List<EfaturaIrsaliyeLine> lines;

  EfaturaIrsaliyeValue({
    this.id,
    this.tarihi,
    this.ettn,
    this.entegreEttn,
    this.vergino,
    this.efaturaNo,
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
      tarihi: (json['Tarihi'] ?? json['Tarih'])?.toString().trim(),
      ettn: (json['ETTN'] ?? json['Ettn'] ?? json['ettn'])?.toString().trim(),
      entegreEttn:
          (json['Entegre_ETTN'] ??
                  json['Entegre_Ettn'] ??
                  json['EntegreEttn'] ??
                  json['entegre_ETTN'] ??
                  json['entegreEttn'])
              ?.toString()
              .trim(),
      vergino:
          (json['Vergino'] ?? json['VergiNo'] ?? json['Vkn'] ?? json['VKN'])
              ?.toString()
              .trim(),
        efaturaNo:
          (json['EfaturaNo'] ??
              json['E_FaturaNo'] ??
              json['FaturaNo'] ??
              json['Faturano'] ??
              json['BelgeNo'])
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
  final String? irsEttn;
  final String? stokKod;
  final String? hizmet;
  final double? miktar;
  final String? birim;
  final double? fiyat;
  final double? tutar;

  EfaturaIrsaliyeLine({
    required this.id,
    this.irsEttn,
    this.stokKod,
    this.hizmet,
    this.miktar,
    this.birim,
    this.fiyat,
    this.tutar,
  });

  factory EfaturaIrsaliyeLine.fromJson(Map<String, dynamic> json) {
    final miktarRaw = json['Miktar'] ?? json['miktar'];
    final fiyatRaw = json['Fiyat'] ?? json['BirimFiyat'] ?? json['birimFiyat'];
    final tutarRaw =
        json['Tutar'] ?? json['Toplam'] ?? json['Net'] ?? json['tutar'];

    return EfaturaIrsaliyeLine(
      id: json['Id'] ?? 0,
      irsEttn: (json['IrsETTN'] ?? json['IrsEttn'] ?? json['irsETTN'] ?? json['irsEttn'])
          ?.toString()
          .trim(),
      stokKod: (json['StokKod'] ?? json['Stokkod'] ?? json['stokKod'])
          ?.toString()
          .trim(),
      hizmet: (json['Hizmet'] ?? json['Aciklama'] ?? json['StokAd'] ?? json['stokAd'])
          ?.toString()
          .trim(),
      miktar: (miktarRaw is num) ? miktarRaw.toDouble() : double.tryParse('$miktarRaw'),
      birim: (json['Birim'] ?? json['birim'])?.toString().trim(),
      fiyat: (fiyatRaw is num) ? fiyatRaw.toDouble() : double.tryParse('$fiyatRaw'),
      tutar: (tutarRaw is num) ? tutarRaw.toDouble() : double.tryParse('$tutarRaw'),
    );
  }
}

