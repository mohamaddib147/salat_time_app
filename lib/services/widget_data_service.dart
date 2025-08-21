import 'dart:async';
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../prayer_times_provider.dart';

// TODO: FIX WIDGET DATA SERVICE - Next prayer logic not working correctly
// Issues identified:
// 1. Widget consistently shows Fajr instead of actual next prayer (e.g., Asr)
// 2. DateTime comparison logic may have edge cases or timezone issues
// 3. API response parsing might be inconsistent with time formats
// 4. Need to verify prayer time offsets are being applied correctly
// 5. Background refresh may not be updating stored epoch properly
// 6. Consider adding debug logging to trace computation steps
// 7. Verify HomeWidget.saveWidgetData is actually persisting to native side
class WidgetDataService {
  static const String appGroupId = 'group.com.example.salat_time'; // iOS App Group (update in iOS setup)
  static const String androidWidgetProvider = 'com.example.salat_time.NextPrayerWidgetProvider';

  static const String keyNextPrayerName = 'widget_next_prayer_name';
  static const String keyNextPrayerCountdown = 'widget_next_prayer_countdown';
  static const String keyNextPrayerEpoch = 'widget_next_prayer_epoch'; // milliseconds since epoch as String
  static const String keyTimesJson = 'widget_times_json'; // JSON map of adjusted five prayer times HH:mm

  // Compute next prayer using PrayerTimesProvider logic and persist for widgets
  static Future<void> updateNextPrayerData([PrayerTimesProvider? provider]) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Access currently computed next prayer if available
      String? nextName = provider?.nextPrayerName;
  DateTime? nextTime = provider?.nextPrayerDateTime;

      // If not available, attempt to fetch based on last known location
      if (nextName == null || nextTime == null) {
        // Fallback: try to re-fetch for current position (no-op if already set)
        // This relies on provider having loaded coordinates earlier
        // We don't call network here to avoid long background operations unnecessarily
        // Try to compute from stored preferences without relying on provider
        final lat = prefs.getDouble('lastLatitude');
        final lon = prefs.getDouble('lastLongitude');
        final method = prefs.getInt('calculationMethod') ?? 2;
        if (lat != null && lon != null) {
          final url = Uri.parse(
              'https://api.aladhan.com/v1/timings/${DateTime.now().toString().split(' ')[0]}?latitude=$lat&longitude=$lon&method=$method');
          try {
            final resp = await http.get(url, headers: {'User-Agent': 'SalatTimeApp/1.0'});
            if (resp.statusCode == 200) {
              final data = json.decode(resp.body);
              if (data['code'] == 200) {
                final Map<String, dynamic> timings = Map<String, dynamic>.from(data['data']['timings']);
                // Load per-prayer offsets
                final offsetsJson = prefs.getString('perPrayerOffsets');
                final Map<String, int> offsets = {
                  'Imsak': 0,
                  'Fajr': 0,
                  'Sunrise': 0,
                  'Dhuhr': 0,
                  'Asr': 0,
                  'Maghrib': 0,
                  'Isha': 0,
                };
                if (offsetsJson != null) {
                  try {
                    final decoded = jsonDecode(offsetsJson);
                    if (decoded is Map) {
                      decoded.forEach((k, v) {
                        if (offsets.containsKey(k)) {
                          if (v is int) offsets[k] = v;
                          if (v is String) offsets[k] = int.tryParse(v) ?? 0;
                        }
                      });
                    }
                  } catch (_) {}
                }

                final result = _computeNextFromTimings(timings, offsets);
                nextName = result.$1;
                nextTime = result.$2; // already UTC
              }
            }
          } catch (_) {}
        }
      }

      if (nextName == null || nextTime == null) {
        await _saveForWidget('-', '--:--:--');
        return;
      }

      // Normalize to UTC for consistent math across app/widget
      final nextUtc = nextTime.toUtc();
      final nowUtc = DateTime.now().toUtc();
      Duration diff = nextUtc.difference(nowUtc);
      if (diff.isNegative) diff = Duration.zero;
      final countdown = _formatDuration(diff);

      // Debug logging
      // ignore: avoid_print
      print('[WidgetDataService] next=$nextName at UTC ${nextUtc.toIso8601String()} epoch=${nextUtc.millisecondsSinceEpoch} countdown=$countdown');

      await prefs.setString(keyNextPrayerName, nextName);
      await prefs.setString(keyNextPrayerCountdown, countdown);
      // Store epoch as string to avoid platform int size limits; use UTC epoch
      await prefs.setString(keyNextPrayerEpoch, nextUtc.millisecondsSinceEpoch.toString());

      // Also persist today's adjusted five prayer times (HH:mm, 24h) so the native widget
      // can compute the next prayer locally each minute without extra network calls.
      final Map<String, String> adjustedTimes = {};
      final Map<String, dynamic>? rawTimes = provider?.prayerTimes;
      final Map<String, int> offs = provider?.prayerOffsets ?? const {
        'Fajr': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0,
      };
      if (rawTimes != null) {
        final nowLocal = DateTime.now();
        final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
        for (final p in const ['Fajr','Dhuhr','Asr','Maghrib','Isha']) {
          final v = rawTimes[p];
          if (v == null) continue;
          try {
            final parts = v.toString().split(':');
            if (parts.length < 2) continue;
            var h = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), ''));
            final m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
            // Build local DateTime, apply per-prayer offset, then format back to HH:mm 24h
            var dt = todayLocal.add(Duration(hours: h, minutes: m));
            dt = dt.add(Duration(minutes: offs[p] ?? 0));
            h = dt.hour; // after offset
            final mm = dt.minute;
            adjustedTimes[p] = '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}' ;
          } catch (_) {}
        }
        if (adjustedTimes.isNotEmpty) {
          await prefs.setString(keyTimesJson, jsonEncode(adjustedTimes));
          await HomeWidget.saveWidgetData<String>(keyTimesJson, jsonEncode(adjustedTimes));
        }
      }

      await _saveForWidget(nextName, countdown,
        epochMillis: nextUtc.millisecondsSinceEpoch);
    } catch (_) {
      // Silent fail; widgets will show dashes
      // ignore: avoid_print
      print('[WidgetDataService] update failed; saving dashes');
      await _saveForWidget('-', '--:--:--');
    }
  }

  static (String?, DateTime?) _computeNextFromTimings(Map<String, dynamic> times, Map<String, int> offsets) {
    // Use local wall-clock for constructing times, convert to UTC for comparison/storage
    final nowUtc = DateTime.now().toUtc();
    final nowLocal = DateTime.now();
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    String? nextName;
    DateTime? nextTime;
    
    // Only consider the five daily prayers for the widget's "next"
    const order = ['Fajr','Dhuhr','Asr','Maghrib','Isha'];
    
    // Find first prayer today that hasn't passed
    for (final prayer in order) {
      final value = times[prayer];
      if (value == null) continue;
      try {
        final parts = value.toString().split(':');
        if (parts.length < 2) continue;
        final h = int.parse(parts[0]);
        // Some APIs return suffix like "05:12 (EDT)", keep only leading digits for minutes
        final m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        var dtLocal = todayLocal.add(Duration(hours: h, minutes: m));
        dtLocal = dtLocal.add(Duration(minutes: offsets[prayer] ?? 0));
        final dtUtc = dtLocal.toUtc();
        
        // Use a small buffer (30 seconds) to avoid edge cases with timing
        if (dtUtc.isAfter(nowUtc.add(const Duration(seconds: 30)))) {
          nextName = prayer;
          nextTime = dtUtc;
          break;
        }
      } catch (_) {}
    }
    
    // If no prayer found today, next is tomorrow's Fajr
    if (nextName == null) {
      final fajr = times['Fajr']?.toString();
      if (fajr != null) {
        try {
          final parts = fajr.split(':');
          if (parts.length >= 2) {
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
            var tomorrowLocal = todayLocal.add(const Duration(days: 1));
            var dtLocal = tomorrowLocal.add(Duration(hours: h, minutes: m));
            dtLocal = dtLocal.add(Duration(minutes: offsets['Fajr'] ?? 0));
            nextName = 'Fajr';
            nextTime = dtLocal.toUtc();
          }
        } catch (_) {}
      }
    }
    return (nextName, nextTime);
  }

  // Visible for unit tests: same logic as _computeNextFromTimings but with injectable nowUtc/nowLocal
  static (String?, DateTime?) computeNextFromTimingsForTest(
    Map<String, dynamic> times,
    Map<String, int> offsets, {
    required DateTime nowUtc,
    required DateTime nowLocal,
  }) {
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    String? nextName;
    DateTime? nextTime;
    const order = ['Fajr','Dhuhr','Asr','Maghrib','Isha'];
    for (final prayer in order) {
      final value = times[prayer];
      if (value == null) continue;
      try {
        final parts = value.toString().split(':');
        if (parts.length < 2) continue;
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        var dtLocal = todayLocal.add(Duration(hours: h, minutes: m));
        dtLocal = dtLocal.add(Duration(minutes: offsets[prayer] ?? 0));
        final dtUtc = dtLocal.toUtc();
        if (dtUtc.isAfter(nowUtc.add(const Duration(seconds: 30)))) {
          nextName = prayer;
          nextTime = dtUtc;
          break;
        }
      } catch (_) {}
    }
    if (nextName == null) {
      final fajr = times['Fajr']?.toString();
      if (fajr != null) {
        try {
          final parts = fajr.split(':');
          if (parts.length >= 2) {
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
            var tomorrowLocal = todayLocal.add(const Duration(days: 1));
            var dtLocal = tomorrowLocal.add(Duration(hours: h, minutes: m));
            dtLocal = dtLocal.add(Duration(minutes: offsets['Fajr'] ?? 0));
            nextName = 'Fajr';
            nextTime = dtLocal.toUtc();
          }
        } catch (_) {}
      }
    }
    return (nextName, nextTime);
  }

  static String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }

  static Future<void> _saveForWidget(String name, String countdown, {int? epochMillis}) async {
    await HomeWidget.saveWidgetData<String>(keyNextPrayerName, name);
    await HomeWidget.saveWidgetData<String>(keyNextPrayerCountdown, countdown);
    if (epochMillis != null) {
      await HomeWidget.saveWidgetData<String>(keyNextPrayerEpoch, epochMillis.toString());
    }
    await HomeWidget.updateWidget(name: androidWidgetProvider, iOSName: 'NextPrayerWidget');
  }
}
