import 'sube.dart';

class SubeResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<Sube> value;

  SubeResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory SubeResponse.fromJson(Map<String, dynamic> json) {
    return SubeResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((sube) => Sube.fromJson(sube))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSucceded': isSucceded,
      'message': message,
      'messageList': messageList,
      'value': value.map((sube) => sube.toJson()).toList(),
    };
  }
}

