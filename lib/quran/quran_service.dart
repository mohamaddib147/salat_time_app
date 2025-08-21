import 'package:quran/quran.dart' as quran;

class QuranService {
  // Get list of all surahs with meta
  List<Map<String, dynamic>> getAllSurahs() {
    return List.generate(114, (i) {
      final index = i + 1;
      return {
        'index': index,
        'name': quran.getSurahNameArabic(index),
        'englishName': quran.getSurahName(index),
        'verses': quran.getVerseCount(index),
        'startPage': quran.getPageNumber(index, 1),
      };
    });
  }

  // Get verses for a given mushaf page (1..604) - basic text only
  List<Map<String, dynamic>> getPageVerses(int page) {
    final verses = quran.getVersesTextByPage(page);
    return List.generate(verses.length, (i) => {
          'text': verses[i],
        });
  }

  // New: Get precise verse refs for a page with surah/ayah and text
  List<Map<String, dynamic>> getPageVerseRefs(int page) {
    final list = <Map<String, dynamic>>[];
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        if (quran.getPageNumber(s, v) == page) {
          list.add({
            'surah': s,
            'ayah': v,
            'text': quran.getVerse(s, v, verseEndSymbol: false),
          });
        }
      }
    }
    return list;
  }

  // Get surah on a given page (first verse on page)
  Map<String, dynamic> getPageSurahInfo(int page) {
    int? surahIdx;
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        if (quran.getPageNumber(s, v) == page) {
          surahIdx = s;
          break;
        }
      }
      if (surahIdx != null) break;
    }
    final idx = surahIdx ?? 1;
    return {
      'index': idx,
      'name': quran.getSurahNameArabic(idx),
      'englishName': quran.getSurahName(idx),
    };
  }

  // Simple keyword search (Arabic contains)
  List<Map<String, dynamic>> search(String query, {int max = 100}) {
    final results = <Map<String, dynamic>>[];
    if (query.trim().isEmpty) return results;
  final q = stripHarakat(query.trim());
    for (int s = 1; s <= 114; s++) {
      final verses = quran.getVerseCount(s);
      for (int v = 1; v <= verses; v++) {
    final raw = quran.getVerse(s, v, verseEndSymbol: false);
    final text = stripHarakat(raw);
    if (text.contains(q)) {
          results.add({
            'surah': s,
            'ayah': v,
      'text': raw,
            'page': quran.getPageNumber(s, v),
          });
          if (results.length >= max) return results;
        }
      }
    }
    return results;
  }

  // Map short codes to quran.Translation enum
  quran.Translation _mapTranslation(String code) {
    switch (code) {
      case 'enSaheeh':
        return quran.Translation.enSaheeh;
      case 'enClearQuran':
        return quran.Translation.enClearQuran;
      case 'urdu':
        return quran.Translation.urdu;
      case 'indonesian':
        return quran.Translation.indonesian;
      case 'turkish':
        return quran.Translation.trSaheeh;
      case 'french':
        return quran.Translation.frHamidullah;
      case 'bengali':
        return quran.Translation.bengali;
      case 'russian':
        return quran.Translation.ruKuliev;
      case 'spanish':
        return quran.Translation.spanish;
      case 'portuguese':
        return quran.Translation.portuguese;
      default:
        return quran.Translation.enSaheeh;
    }
  }

  String getVerseTranslation(int surah, int ayah, String code) {
    final t = _mapTranslation(code);
    return quran.getVerseTranslation(surah, ayah, verseEndSymbol: false, translation: t);
  }

  // Standardized segments for a page by scanning surahs/verses
  List<Map<String, int>> getPageSegments(int page) {
    // Prefer the package API for performance/accuracy
    final segments = <Map<String, int>>[];
    try {
      final data = quran.getPageData(page);
      for (final d in data) {
        // Handle possible key names across versions
        final s = (d['surahNumber'] ?? d['surah'] ?? d['s']) as int?;
        final start = (d['startVerse'] ?? d['start'] ?? d['from']) as int?;
        final end = (d['endVerse'] ?? d['end'] ?? d['to']) as int?;
        if (s != null && start != null && end != null) {
          segments.add({'surah': s, 'start': start, 'end': end});
        }
      }
      if (segments.isNotEmpty) return segments;
    } catch (_) {
      // Fall back to scanning below
    }

    // Fallback by scanning surahs/verses
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      int v = 1;
      while (v <= count) {
        if (quran.getPageNumber(s, v) == page) {
          final start = v;
          while (v <= count && quran.getPageNumber(s, v) == page) {
            v++;
          }
          final end = v - 1;
          segments.add({'surah': s, 'start': start, 'end': end});
        } else {
          v++;
        }
      }
    }
    return segments;
  }

  // Juz for the first verse on the page
  int getJuzForPage(int page) {
    final segs = getPageSegments(page);
    if (segs.isNotEmpty) {
      final s = segs.first['surah']!;
      final v = segs.first['start']!;
      return quran.getJuzNumber(s, v);
    }
    // Fallback via scanning
    final refs = getPageVerseRefs(page);
    if (refs.isNotEmpty) {
      final s = refs.first['surah'] as int;
      final v = refs.first['ayah'] as int;
      return quran.getJuzNumber(s, v);
    }
    return 1;
  }

  bool isSajdah(int surah, int ayah) => quran.isSajdahVerse(surah, ayah);

  String getSurahNameArabicByIndex(int surah) => quran.getSurahNameArabic(surah);

  String getPlaceLabel(int surah) {
    final place = quran.getPlaceOfRevelation(surah); // 'Makkah' or 'Madinah'
    if (place.toLowerCase().contains('mad')) return 'Madani';
    return 'Makki';
  }

  ({int start, int end}) getSurahPageRange(int surah) {
    final pages = quran.getSurahPages(surah);
    if (pages.isEmpty) return (start: quran.getPageNumber(surah, 1), end: quran.getPageNumber(surah, quran.getVerseCount(surah)));
    pages.sort();
    return (start: pages.first, end: pages.last);
    }

  int getFirstPageOfJuz(int juz) {
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        if (quran.getJuzNumber(s, v) == juz) {
          return quran.getPageNumber(s, v);
        }
      }
    }
    return 1;
  }

  // Last page of a Juz (based on next Juz start)
  int getLastPageOfJuz(int juz) {
    if (juz >= quran.totalJuzCount) return quran.totalPagesCount;
    final nextStart = getFirstPageOfJuz(juz + 1);
    return (nextStart - 1).clamp(1, quran.totalPagesCount);
  }

  // Page range for a Juz
  ({int start, int end}) getJuzPageRange(int juz) {
    final start = getFirstPageOfJuz(juz);
    final end = getLastPageOfJuz(juz);
    return (start: start, end: end);
  }

  // Starting (surah, ayah, page) of a Juz
  ({int surah, int ayah, int page}) getJuzStartRef(int juz) {
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        if (quran.getJuzNumber(s, v) == juz) {
          return (surah: s, ayah: v, page: quran.getPageNumber(s, v));
        }
      }
    }
    return (surah: 1, ayah: 1, page: 1);
  }

  // Quran.com URLs
  String getJuzURL(int juz) => quran.getJuzURL(juz);
  String getSurahURL(int surah) => quran.getSurahURL(surah);
  String getVerseURL(int surah, int ayah) => quran.getVerseURL(surah, ayah);

  // Multi-word searches
  Map<String, dynamic> searchWords(List<String> words) {
    final res = quran.searchWords(words);
    return Map<String, dynamic>.from(res);
  }
  Map<String, dynamic> searchWordsInTranslation(List<String> words, String code) {
    final res = quran.searchWordsInTranslation(words, translation: _mapTranslation(code));
    return Map<String, dynamic>.from(res);
  }

  // Strip Arabic diacritics (harakāt) for improved search
  String stripHarakat(String input) {
    const marks =
        '\\u0610\\u0611\\u0612\\u0613\\u0614\\u0615\\u0616\\u0617\\u0618\\u0619\\u061A\\u064B\\u064C\\u064D\\u064E\\u064F\\u0650\\u0651\\u0652\\u0653\\u0654\\u0655\\u0656\\u0657\\u0658\\u0659\\u065A\\u065B\\u065C\\u065D\\u065E\\u065F\\u0670\\u06D6\\u06D7\\u06D8\\u06D9\\u06DA\\u06DB\\u06DC\\u06DF\\u06E0\\u06E1\\u06E2\\u06E3\\u06E4\\u06E7\\u06E8\\u06EA\\u06EB\\u06EC\\u06ED';
    final reg = RegExp('[' + marks + ']');
    return input.replaceAll(reg, '');
  }

  // Search in translations by simple contains (efficient enough on-device)
  List<Map<String, dynamic>> searchInTranslation(String query, String code, {int max = 100}) {
    final results = <Map<String, dynamic>>[];
    if (query.trim().isEmpty) return results;
    final q = query.trim().toLowerCase();
    final t = _mapTranslation(code);
    for (int s = 1; s <= 114; s++) {
      final count = quran.getVerseCount(s);
      for (int v = 1; v <= count; v++) {
        final tr = quran.getVerseTranslation(s, v, verseEndSymbol: false, translation: t);
        if (tr.toLowerCase().contains(q)) {
          results.add({
            'surah': s,
            'ayah': v,
            'text': tr,
            'page': quran.getPageNumber(s, v),
          });
          if (results.length >= max) return results;
        }
      }
    }
    return results;
  }
}
