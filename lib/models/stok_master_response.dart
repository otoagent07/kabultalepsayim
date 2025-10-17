import 'stok_master.dart';

class StokMasterResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<StokMaster> value;

  StokMasterResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory StokMasterResponse.fromJson(Map<String, dynamic> json) {
    return StokMasterResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((item) => StokMaster.fromJson(item))
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
