class MalKabulSaveResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final dynamic value;

  MalKabulSaveResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    this.value,
  });

  factory MalKabulSaveResponse.fromJson(Map<String, dynamic> json) {
    return MalKabulSaveResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSucceded': isSucceded,
      'message': message,
      'messageList': messageList,
      'value': value,
    };
  }
}
