import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/show_models.dart';

class Storage {
  static const String _key = "tracked_shows";

  /// Save the current list of shows
  static Future<void> saveShows(List<Show> shows) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = shows.map((s) => s.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  /// Load the saved list of shows
  static Future<List<Show>> loadShows() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((j) => Show.fromJson(j)).toList();
  }
}
