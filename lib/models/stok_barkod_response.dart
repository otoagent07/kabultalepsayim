import 'stok_barkod.dart';

class StokBarkodResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<StokBarkod> value;

  StokBarkodResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory StokBarkodResponse.fromJson(Map<String, dynamic> json) {
    return StokBarkodResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value:
          (json['value'] as List<dynamic>?)
              ?.map((item) => StokBarkod.fromJson(item))
              .toList() ??
          [],
    );
  }
}
