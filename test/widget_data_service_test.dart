import 'package:flutter_test/flutter_test.dart';
import 'package:salat_time/services/widget_data_service.dart';

void main() {
  group('WidgetDataService.computeNextFromTimingsForTest', () {
    // Common timings map similar to Aladhan (24h local strings)
    final baseTimings = <String, dynamic>{
      'Fajr': '05:00',
      'Sunrise': '06:15',
      'Dhuhr': '12:30',
      'Asr': '15:45',
      'Maghrib': '18:20',
      'Isha': '19:45',
    };
    final zeroOffsets = <String, int>{
      'Imsak': 0, 'Fajr': 0, 'Sunrise': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0,
    };

    test('mid-day: next is Dhuhr just before it', () {
      // Local time 12:29:10, UTC assumed equal for test simplicity
      final nowLocal = DateTime(2025, 8, 21, 12, 29, 10);
      final nowUtc = DateTime.utc(2025, 8, 21, 12, 29, 10);

      final (name, timeUtc) = WidgetDataService.computeNextFromTimingsForTest(
        baseTimings, zeroOffsets, nowUtc: nowUtc, nowLocal: nowLocal,
      );

      expect(name, 'Dhuhr');
      expect(timeUtc, isNotNull);
      // The computed time should be after now (by more than the 30s buffer)
      expect(timeUtc!.isAfter(nowUtc.add(const Duration(seconds: 30))), isTrue);
    });

    test('buffer window: prayer within 20s should skip to next', () {
      // Now at 12:29:50, Dhuhr at 12:30:00 (10s ahead) -> within 30s buffer => expect Asr
      final nowLocal = DateTime(2025, 8, 21, 12, 29, 50);
      final nowUtc = DateTime.utc(2025, 8, 21, 12, 29, 50);

      final (name, _) = WidgetDataService.computeNextFromTimingsForTest(
        baseTimings, zeroOffsets, nowUtc: nowUtc, nowLocal: nowLocal,
      );

      expect(name, 'Asr');
    });

    test('after Isha: fallback to tomorrow Fajr', () {
      // After all prayers today -> expect tomorrow's Fajr
      final nowLocal = DateTime(2025, 8, 21, 22, 00, 00);
      final nowUtc = DateTime.utc(2025, 8, 21, 20, 00, 00); // allow non-equal tz offset

      final (name, timeUtc) = WidgetDataService.computeNextFromTimingsForTest(
        baseTimings, zeroOffsets, nowUtc: nowUtc, nowLocal: nowLocal,
      );

      expect(name, 'Fajr');
      expect(timeUtc, isNotNull);
      // Should be roughly 2025-08-22T05:00 local converted to UTC; just assert it is after now by > 1h
      expect(timeUtc!.isAfter(nowUtc.add(const Duration(hours: 1))), isTrue);
    });

    test('offsets applied: +10min to Asr shifts next selection', () {
      final offsets = Map<String, int>.from(zeroOffsets);
      offsets['Asr'] = 10; // delay Asr by 10 minutes

      // At 12:29:50 (Dhuhr at 12:30 within 10s buffer) -> skip Dhuhr, next is Asr 15:55 due to offset
      final nowLocal = DateTime(2025, 8, 21, 12, 29, 50);
      final nowUtc = DateTime.utc(2025, 8, 21, 12, 29, 50);

      final (name, _) = WidgetDataService.computeNextFromTimingsForTest(
        baseTimings, offsets, nowUtc: nowUtc, nowLocal: nowLocal,
      );

      expect(name, 'Asr');
    });
  });
}
