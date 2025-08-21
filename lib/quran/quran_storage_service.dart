import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuranStorageService {
  static const _kBookmarksKey = 'quran_bookmarks';
  static const _kLastPageKey = 'quran_last_page';

  Future<List<int>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBookmarksKey);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBookmarks(List<int> pages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBookmarksKey, jsonEncode(pages));
  }

  Future<int?> loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kLastPageKey);
    return v;
  }

  Future<void> saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastPageKey, page);
  }
}
