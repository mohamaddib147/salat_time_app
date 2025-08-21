import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'audio_service.dart';
import 'notification_service.dart';
import 'widget_data_service.dart';

// The callback MUST be a top-level or static function for background execution.
@pragma('vm:entry-point')
Future<void> adhanCallback(int id) async {
  try {
    // Initialize services for background operation
    await NotificationService().init();
    
    // Get prayer name from ID
    final prayerName = _prayerNameFromId(id);
    if (prayerName == null) return;
    
  // Show notification first (so user sees it), then play Adhan
  await NotificationService().showAdhanNotification(prayerName);
  await AudioService().playAdhanFor(prayerName);
  } catch (e) {
    // Silent fail in background
  }
}

// A separate callback to refresh the home widget periodically
@pragma('vm:entry-point')
Future<void> widgetRefreshCallback() async {
  try {
    // Minimal init: compute using stored prefs if provider not available
    await WidgetDataService.updateNextPrayerData();
  // Schedule next refresh
  await PrayerTimeScheduler.scheduleWidgetRefresh();
  } catch (_) {}
}

// Assign stable IDs per prayer so we can infer the name in the callback
const int _idFajr = 2001;
const int _idDhuhr = 2002;
const int _idAsr = 2003;
const int _idMaghrib = 2004;
const int _idIsha = 2005;

String? _prayerNameFromId(int id) {
  switch (id) {
    case _idFajr:
      return 'Fajr';
    case _idDhuhr:
      return 'Dhuhr';
    case _idAsr:
      return 'Asr';
    case _idMaghrib:
      return 'Maghrib';
    case _idIsha:
      return 'Isha';
    default:
      return null;
  }
}

class PrayerTimeScheduler {
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();
  }

  // Schedules alarms for today based on coordinates and calc method
  static Future<void> scheduleForToday({
    required double latitude,
    required double longitude,
    required int calculationMethod,
    Map<String, int>? prayerOffsets,
    Map<String, bool>? adhanEnabled,
    bool notificationsEnabled = true,
  }) async {
    try {
      if (!notificationsEnabled) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = Uri.parse('https://api.aladhan.com/v1/timings/$today?latitude=$latitude&longitude=$longitude&method=$calculationMethod');
      final res = await http.get(url);
      if (res.statusCode != 200) return;
      final data = json.decode(res.body);
      if (data['code'] != 200) return;
      final timings = Map<String, dynamic>.from(data['data']['timings']);

      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      const prayers = ['Fajr','Dhuhr','Asr','Maghrib','Isha'];
      for (final name in prayers) {
        if (adhanEnabled != null && adhanEnabled[name] == false) continue;
        final t = timings[name];
        if (t == null) continue;
        final parts = t.split(':');
        if (parts.length != 2) continue;
        var dt = base.add(Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1])));
        final offset = prayerOffsets != null ? (prayerOffsets[name] ?? 0) : 0;
        dt = dt.add(Duration(minutes: offset));
        if (dt.isBefore(now)) continue; // don't schedule past times

        final alarmId = {
          'Fajr': _idFajr,
          'Dhuhr': _idDhuhr,
          'Asr': _idAsr,
          'Maghrib': _idMaghrib,
          'Isha': _idIsha,
        }[name]!;

        await AndroidAlarmManager.oneShotAt(
          dt,
          alarmId,
          adhanCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          rescheduleOnReboot: true,
          allowWhileIdle: true,
        );
      }
    } catch (_) {}
  }

  // Schedule a repeating-like refresh by scheduling the next one each run
  static Future<void> scheduleWidgetRefresh({Duration interval = const Duration(minutes: 5)}) async {
    try {
      final when = DateTime.now().add(interval);
      await AndroidAlarmManager.oneShotAt(
        when,
        2999, // unique ID for widget refresh
        widgetRefreshCallback,
  exact: false,
  wakeup: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    } catch (_) {}
  }

  // Schedules a test Adhan alarm in [delay] for the given [prayerName]
  static Future<void> scheduleTestAlarm({Duration delay = const Duration(minutes: 1), String prayerName = 'Asr'}) async {
    final when = DateTime.now().add(delay);
    final id = {
      'Fajr': _idFajr,
      'Dhuhr': _idDhuhr,
      'Asr': _idAsr,
      'Maghrib': _idMaghrib,
      'Isha': _idIsha,
    }[prayerName] ?? _idAsr;

    try {
      await AndroidAlarmManager.oneShotAt(
        when,
        id,
        adhanCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
    } catch (_) {}
  }
}
