import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';

class StorageService {
  static const String _medicinesKey = 'medicines';

  Future<void> saveMedicines(List<Medicine> medicines) async {
    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> jsonList = medicines
        .map((medicine) => medicine.toJson())
        .toList();

    await prefs.setString(_medicinesKey, jsonEncode(jsonList));
  }

  Future<List<Medicine>> loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();

    final String? storedData = prefs.getString(_medicinesKey);

    if (storedData == null) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(storedData);

    return jsonList
        .map((json) => Medicine.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearMedicines() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_medicinesKey);
  }
}
