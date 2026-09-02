import 'package:shared_preferences/shared_preferences.dart';

import '../models/medicine.dart';

class StorageService {
  static const String _medicineNameKey = 'medicine_name';
  static const String _medicineHourKey = 'medicine_hour';
  static const String _medicineMinuteKey = 'medicine_minute';

  Future<void> saveMedicine(Medicine medicine) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_medicineNameKey, medicine.name);

    await prefs.setInt(_medicineHourKey, medicine.hour);

    await prefs.setInt(_medicineMinuteKey, medicine.minute);
  }

  Future<Medicine?> loadMedicine() async {
    final prefs = await SharedPreferences.getInstance();

    final String? name = prefs.getString(_medicineNameKey);
    final int? hour = prefs.getInt(_medicineHourKey);
    final int? minute = prefs.getInt(_medicineMinuteKey);

    if (name == null || hour == null || minute == null) {
      return null;
    }

    return Medicine(name: name, hour: hour, minute: minute);
  }

  Future<void> clearMedicine() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_medicineNameKey);
    await prefs.remove(_medicineHourKey);
    await prefs.remove(_medicineMinuteKey);
  }
}
