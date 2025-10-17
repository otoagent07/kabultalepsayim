class ApiUser {
  final int fldUserID;
  final String fldName;
  final String fldSurname;
  final String fldUserName;
  final String fldPassword;
  final int fldRole;
  final String? fldEPosta;
  final String? fldTel;
  final String fldOteller;
  final int fldSirketID;
  final String? fldKolayMenu;
  final String? fldFrontMenu;
  final String? fldBackMenu;

  ApiUser({
    required this.fldUserID,
    required this.fldName,
    required this.fldSurname,
    required this.fldUserName,
    required this.fldPassword,
    required this.fldRole,
    this.fldEPosta,
    this.fldTel,
    required this.fldOteller,
    required this.fldSirketID,
    this.fldKolayMenu,
    this.fldFrontMenu,
    this.fldBackMenu,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      fldUserID: json['fldUserID'] ?? 0,
      fldName: json['fldName'] ?? '',
      fldSurname: json['fldSurname'] ?? '',
      fldUserName: json['fldUserName'] ?? '',
      fldPassword: json['fldPassword'] ?? '',
      fldRole: json['fldRole'] ?? 0,
      fldEPosta: json['fldEPosta'],
      fldTel: json['fldTel'],
      fldOteller: json['fldOteller'] ?? '',
      fldSirketID: json['fldSirketID'] ?? 0,
      fldKolayMenu: json['fldKolayMenu'],
      fldFrontMenu: json['fldFrontMenu'],
      fldBackMenu: json['fldBackMenu'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fldUserID': fldUserID,
      'fldName': fldName,
      'fldSurname': fldSurname,
      'fldUserName': fldUserName,
      'fldPassword': fldPassword,
      'fldRole': fldRole,
      'fldEPosta': fldEPosta,
      'fldTel': fldTel,
      'fldOteller': fldOteller,
      'fldSirketID': fldSirketID,
      'fldKolayMenu': fldKolayMenu,
      'fldFrontMenu': fldFrontMenu,
      'fldBackMenu': fldBackMenu,
    };
  }
}
