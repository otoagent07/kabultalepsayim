import 'stok_birim_fiyat.dart';

class StokBirimFiyatResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<StokBirimFiyat> value;

  StokBirimFiyatResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory StokBirimFiyatResponse.fromJson(Map<String, dynamic> json) {
    return StokBirimFiyatResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((item) => StokBirimFiyat.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSucceded': isSucceded,
      'message': message,
      'messageList': messageList,
      'value': value.map((item) => item.toJson()).toList(),
    };
  }
}
