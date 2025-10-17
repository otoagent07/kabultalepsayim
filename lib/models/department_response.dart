import 'department.dart';

class DepartmentResponse {
  final bool isSucceded;
  final String? message;
  final List<dynamic> messageList;
  final List<Department> value;

  DepartmentResponse({
    required this.isSucceded,
    this.message,
    required this.messageList,
    required this.value,
  });

  factory DepartmentResponse.fromJson(Map<String, dynamic> json) {
    return DepartmentResponse(
      isSucceded: json['isSucceded'] ?? false,
      message: json['message'],
      messageList: json['messageList'] ?? [],
      value: (json['value'] as List<dynamic>?)
          ?.map((dept) => Department.fromJson(dept))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSucceded': isSucceded,
      'message': message,
      'messageList': messageList,
      'value': value.map((dept) => dept.toJson()).toList(),
    };
  }
}
