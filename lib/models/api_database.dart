class ApiDatabase {
  final int id;
  final int sirketId;
  final int otelId;
  final int programId;
  final String kod;
  final String ad;
  final bool gizliMi;
  final String? grup;
  final String? updateDate;
  final String? dbServer;
  final String? dbCatalog;
  final String? dbUser;
  final String? dbPass;
  final int? dbFrontOfficeId;
  final int? dbDemirbasId;

  ApiDatabase({
    required this.id,
    required this.sirketId,
    required this.otelId,
    required this.programId,
    required this.kod,
    required this.ad,
    required this.gizliMi,
    this.grup,
    this.updateDate,
    this.dbServer,
    this.dbCatalog,
    this.dbUser,
    this.dbPass,
    this.dbFrontOfficeId,
    this.dbDemirbasId,
  });

  factory ApiDatabase.fromJson(Map<String, dynamic> json) {
    return ApiDatabase(
      id: json['id'] ?? 0,
      sirketId: json['sirket_Id'] ?? 0,
      otelId: json['otel_Id'] ?? 0,
      programId: json['program_Id'] ?? 0,
      kod: json['kod'] ?? '',
      ad: json['ad'] ?? '',
      gizliMi: json['gizliMi'] ?? false,
      grup: json['grup'],
      updateDate: json['updateDate'],
      dbServer: json['dbServer'],
      dbCatalog: json['dbCatalog'],
      dbUser: json['dbUser'],
      dbPass: json['dbPass'],
      dbFrontOfficeId: json['dbFrontOffice_Id'],
      dbDemirbasId: json['dbDemirbas_Id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sirket_Id': sirketId,
      'otel_Id': otelId,
      'program_Id': programId,
      'kod': kod,
      'ad': ad,
      'gizliMi': gizliMi,
      'grup': grup,
      'updateDate': updateDate,
      'dbServer': dbServer,
      'dbCatalog': dbCatalog,
      'dbUser': dbUser,
      'dbPass': dbPass,
      'dbFrontOffice_Id': dbFrontOfficeId,
      'dbDemirbas_Id': dbDemirbasId,
    };
  }
}
