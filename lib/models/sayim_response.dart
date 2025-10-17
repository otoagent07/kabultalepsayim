import 'sayim_item.dart';

class SayimResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<SayimItem> value;

  SayimResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory SayimResponse.fromJson(Map<String, dynamic> json) {
    return SayimResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((item) => SayimItem.fromJson(item))
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
