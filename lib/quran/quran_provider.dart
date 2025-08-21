import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_service.dart';
import 'quran_storage_service.dart';

class QuranProvider extends ChangeNotifier {
  final QuranService service;
  final QuranStorageService storage;

  QuranProvider({QuranService? service, QuranStorageService? storage})
      : service = service ?? QuranService(),
        storage = storage ?? QuranStorageService() {
    _init();
  }

  int _currentPage = 1;
  List<int> _bookmarks = [];

  // Settings
  String _font = 'uthman'; // uthman, kfgqpc_an, kufi_ext, kufi_sty, ksa, ksa_heading, amiri, notonaskh, aref
  double _fontSize = 24.0; // pt
  String _marker = 'circle'; // circle, ornate
  String _theme = 'light'; // light, dark
  bool _showTranslation = false;
  String _translationCode = 'enSaheeh'; // default translation
  bool _useVerseEndSymbols = false;
  bool _verseEndArabicNumerals = true;

  int get currentPage => _currentPage;
  List<int> get bookmarks => List.unmodifiable(_bookmarks);

  String get font => _font;
  double get fontSize => _fontSize;
  String get marker => _marker;
  String get theme => _theme;
  bool get showTranslation => _showTranslation;
  String get translationCode => _translationCode;
  bool get useVerseEndSymbols => _useVerseEndSymbols;
  bool get verseEndArabicNumerals => _verseEndArabicNumerals;

  Future<void> _init() async {
    _bookmarks = await storage.loadBookmarks();
    final last = await storage.loadLastPage();
    if (last != null && last >= 1 && last <= 604) {
      _currentPage = last;
    }
    // Load settings
    final prefs = await SharedPreferences.getInstance();
    _font = prefs.getString('q_font') ?? _font;
    _fontSize = prefs.getDouble('q_font_size') ?? _fontSize;
    _marker = prefs.getString('q_marker') ?? _marker;
    _theme = prefs.getString('q_theme') ?? _theme;
    _showTranslation = prefs.getBool('q_trans_show') ?? _showTranslation;
    _translationCode = prefs.getString('q_trans_code') ?? _translationCode;
    _useVerseEndSymbols = prefs.getBool('q_use_ves') ?? _useVerseEndSymbols;
  _verseEndArabicNumerals = prefs.getBool('q_use_ves_ar_num') ?? _verseEndArabicNumerals;
    notifyListeners();
  }

  void setPage(int page) {
    if (page < 1 || page > 604) return;
    if (_currentPage == page) return;
    _currentPage = page;
    storage.saveLastPage(page);
    notifyListeners();
  }

  bool isBookmarked(int page) => _bookmarks.contains(page);

  void toggleBookmark(int page) {
    if (isBookmarked(page)) {
      _bookmarks.remove(page);
    } else {
      _bookmarks.add(page);
      _bookmarks.sort();
    }
    storage.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  void removeBookmark(int page) {
    _bookmarks.remove(page);
    storage.saveBookmarks(_bookmarks);
    notifyListeners();
  }

  Future<void> setFont(String value) async {
    _font = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_font', _font);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value.clamp(16.0, 40.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('q_font_size', _fontSize);
    notifyListeners();
  }

  Future<void> setMarker(String value) async {
    _marker = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_marker', _marker);
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    _theme = value; // 'light' or 'dark'
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_theme', _theme);
    notifyListeners();
  }

  Future<void> setShowTranslation(bool value) async {
    _showTranslation = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('q_trans_show', _showTranslation);
    notifyListeners();
  }

  Future<void> setTranslationCode(String code) async {
    _translationCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_trans_code', _translationCode);
    notifyListeners();
  }

  Future<void> setUseVerseEndSymbols(bool value) async {
    _useVerseEndSymbols = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('q_use_ves', _useVerseEndSymbols);
    notifyListeners();
  }

  Future<void> setVerseEndArabicNumerals(bool value) async {
    _verseEndArabicNumerals = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('q_use_ves_ar_num', _verseEndArabicNumerals);
    notifyListeners();
  }
}
