import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class SharedPreferencesService {
  static const String _photoKey = 'captured_photo';

  static Future<void> savePhoto(XFile photo) async {
    final prefs = await SharedPreferences.getInstance();
    final bytes = await photo.readAsBytes();
    final base64String = base64Encode(bytes);
    await prefs.setString(_photoKey, base64String);
  }

  static Future<String?> getPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_photoKey);
  }

  static Future<void> clearPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_photoKey);
  }
}