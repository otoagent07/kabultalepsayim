import 'barkod_kontrol_item.dart';

class BarkodKontrolResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<BarkodKontrolItem> value;

  BarkodKontrolResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory BarkodKontrolResponse.fromJson(Map<String, dynamic> json) {
    return BarkodKontrolResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value: (json['value'] as List<dynamic>?)
          ?.map((item) => BarkodKontrolItem.fromJson(item))
          .toList() ?? [],
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
