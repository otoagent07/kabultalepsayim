import 'package:flutter/foundation.dart';
import '../models/api_database.dart';
import '../models/api_company.dart';

class SelectedDatabaseProvider extends ChangeNotifier {
  ApiDatabase? _selectedDatabase;
  ApiCompany? _selectedCompany;

  ApiDatabase? get selectedDatabase => _selectedDatabase;
  ApiCompany? get selectedCompany => _selectedCompany;

  void setSelectedDatabase(ApiDatabase database, ApiCompany company) {
    _selectedDatabase = database;
    _selectedCompany = company;
    notifyListeners();
  }

  void clearSelection() {
    _selectedDatabase = null;
    _selectedCompany = null;
    notifyListeners();
  }
}
