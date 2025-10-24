import 'mal_kabul_order_item.dart';

class MalKabulOrderResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<MalKabulOrderItem> value;

  MalKabulOrderResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory MalKabulOrderResponse.fromJson(Map<String, dynamic> json) {
    return MalKabulOrderResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((item) => MalKabulOrderItem.fromJson(item))
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
