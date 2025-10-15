class User {
  final String username;
  final String password;
  final String hotelId;

  User({required this.username, required this.password, required this.hotelId});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password, 'hotelId': hotelId};
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      hotelId: json['hotelId'] ?? '',
    );
  }
}
