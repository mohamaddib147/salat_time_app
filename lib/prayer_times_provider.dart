import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/prayer_time_scheduler.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'services/widget_data_service.dart';

const String _prefsKeyRecentLocations = 'recentLocations';
const String _prefsKeyIs24Hour = 'is24HourFormat';
const String _prefsKeyCalculationMethod = 'calculationMethod';
const String _prefsKeyLastSource = 'lastLocationSource';
const String _prefsKeyLastLat = 'lastLatitude';
const String _prefsKeyLastLon = 'lastLongitude';
const String _prefsKeyLastAddress = 'lastAddress';
const String _prefsKeyShowImsak = 'show_imsak';
const String _prefsKeyTimeOffset = 'timeOffsetMinutes';
// New: per-prayer offsets (JSON stored)
const String _prefsKeyPerPrayerOffsets = 'perPrayerOffsets';

const Map<int, String> calculationMethods = {
  1: 'University of Islamic Sciences, Karachi',
  2: 'Islamic Society of North America (ISNA)',
  3: 'Muslim World League (MWL)',
  4: 'Umm al-Qura University, Makkah',
  5: 'Egyptian General Authority of Survey',
  7: 'Institute of Geophysics, University of Tehran',
  8: 'Gulf Region',
  9: 'Kuwait',
  10: 'Qatar',
  11: 'Majlis Ugama Islam Singapura, Singapore',
  12: 'Union Organization islamic de France',
  13: 'Diyanet İşleri Başkanlığı, Turkey',
  14: 'Spiritual Administration of Muslims of Russia',
  15: 'Moonsighting Committee Worldwide',
  16: 'Dubai (unofficial)',
  0: 'Shia Ithna-Ansari',
  99: 'Islamiska Förbundet (Custom 14.7/13.7)',
};

// Order list removed; we restrict next-prayer logic to the five daily prayers only.

class PrayerTimesProvider extends ChangeNotifier {
  Position? _currentPosition;
  Map<String, dynamic>? _prayerTimes;
  Map<String, dynamic>? _hijriDateInfo;
  Map<String, dynamic>? _gregorianDateInfo;
  String? _errorMessage;
  bool _isLoading = false;
  List<String> _recentLocations = [];
  bool _is24HourFormat = false;
  int _calculationMethod = 2; // ISNA
  String? _lastUsedLocationSource;
  String? _lastUsedCity;
  bool _showImsak = false;
  Timer? _nextPrayerTimer;
  final AudioPlayer _adhanPlayer = AudioPlayer();
  String? _nextPrayerName;
  DateTime? _nextPrayerDateTime;
  // Deprecated single offset (kept for migration only)
  int _timeOffsetMinutes = 0;
  // New: per-prayer offsets map
  Map<String, int> _prayerOffsets = {
    'Imsak': 0,
    'Fajr': 0,
    'Sunrise': 0,
    'Dhuhr': 0,
    'Asr': 0,
    'Maghrib': 0,
    'Isha': 0,
  };
  // Adhan/Notification settings
  bool _notificationsEnabled = true;
  // Per-prayer Adhan enable/disable
  final Map<String, bool> _adhanEnabled = {
    'Fajr': true,
    'Dhuhr': true,
    'Asr': true,
    'Maghrib': true,
    'Isha': true,
  };
  // Per-prayer Adhan file names (falling back to global default in AudioService)
  final Map<String, String?> _adhanFiles = {
    'Fajr': null,
    'Dhuhr': null,
    'Asr': null,
    'Maghrib': null,
    'Isha': null,
  };

  // Getters
  Map<String, dynamic>? get prayerTimes => _showImsak ? _prayerTimes : _filterImsak();
  Map<String, dynamic>? get hijriDateInfo => _hijriDateInfo;
  Map<String, dynamic>? get gregorianDateInfo => _gregorianDateInfo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  List<String> get recentLocations => _recentLocations;
  bool get is24HourFormat => _is24HourFormat;
  int get calculationMethod => _calculationMethod;
  bool get showImsak => _showImsak;
  String? get lastUsedLocationSource => _lastUsedLocationSource;
  String? get nextPrayerName => _nextPrayerName;
  DateTime? get nextPrayerDateTime => _nextPrayerDateTime;
  // New getters for per-prayer offsets
  Map<String, int> get prayerOffsets => Map.unmodifiable(_prayerOffsets);
  int getOffsetFor(String prayer) => _prayerOffsets[prayer] ?? 0;
  bool get notificationsEnabled => _notificationsEnabled;
  bool getAdhanEnabled(String prayer) => _adhanEnabled[prayer] ?? true;
  String? getAdhanFile(String prayer) => _adhanFiles[prayer];

  Map<int, String> get availableCalculationMethods => calculationMethods;

  // Updated: apply per-prayer offset when provided
  String formatTime(String time24, {String? prayerName}) {
    try {
      final parsedTime = DateFormat('HH:mm').parse(time24);
      final offset = prayerName != null ? (_prayerOffsets[prayerName] ?? 0) : 0;
      final adjusted = parsedTime.add(Duration(minutes: offset));
      return _is24HourFormat
          ? DateFormat('HH:mm').format(adjusted)
          : DateFormat('h:mm a').format(adjusted);
    } catch (e) {
      return time24;
    }
  }

  PrayerTimesProvider() {
    _loadPreferences();
  }

  @override
  void dispose() {
    _nextPrayerTimer?.cancel();
  _adhanPlayer.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _filterImsak() {
    if (_prayerTimes == null) return null;
    var filtered = Map<String, dynamic>.from(_prayerTimes!);
    if (!_showImsak) {
      filtered.remove('Imsak');
    }
    return filtered;
  }

  Future<void> fetchTimesByGps() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _errorMessage = 'Location permission denied';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = position;

      // Fetch prayer times using coordinates
      await fetchTimesByCoordinates(position.latitude, position.longitude);
    } catch (e) {
      _errorMessage = 'Error getting location: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _is24HourFormat = prefs.getBool(_prefsKeyIs24Hour) ?? false;
    _calculationMethod = prefs.getInt(_prefsKeyCalculationMethod) ?? 2;
    _showImsak = prefs.getBool(_prefsKeyShowImsak) ?? false;
    _recentLocations = prefs.getStringList(_prefsKeyRecentLocations) ?? [];
    _lastUsedLocationSource = prefs.getString(_prefsKeyLastSource);
    _lastUsedCity = prefs.getString(_prefsKeyLastAddress);
    _timeOffsetMinutes = prefs.getInt(_prefsKeyTimeOffset) ?? 0;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    for (final p in ['Fajr','Dhuhr','Asr','Maghrib','Isha']) {
      _adhanEnabled[p] = prefs.getBool('adhan_enabled_${p.toLowerCase()}') ?? true;
      _adhanFiles[p] = prefs.getString('adhan_file_${p.toLowerCase()}');
    }

    // Load per-prayer offsets if available; otherwise migrate from old single offset
    final perPrayerJson = prefs.getString(_prefsKeyPerPrayerOffsets);
    if (perPrayerJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(perPrayerJson);
        // Preserve known keys, default to 0 if missing
        for (final k in _prayerOffsets.keys) {
          final v = decoded[k];
          if (v is int) _prayerOffsets[k] = v;
          if (v is String) _prayerOffsets[k] = int.tryParse(v) ?? 0;
        }
      } catch (_) {
        // ignore parse errors, keep defaults
      }
    } else {
      // Migrate: apply old global offset to all prayers, then persist
      if (_timeOffsetMinutes != 0) {
        _prayerOffsets.updateAll((key, value) => _timeOffsetMinutes);
      }
      await prefs.setString(_prefsKeyPerPrayerOffsets, jsonEncode(_prayerOffsets));
    }
    
    // If we have a last used location, fetch times for it
    if (_lastUsedLocationSource == 'gps' && 
        prefs.containsKey(_prefsKeyLastLat) && 
        prefs.containsKey(_prefsKeyLastLon)) {
      double lat = prefs.getDouble(_prefsKeyLastLat)!;
      double lon = prefs.getDouble(_prefsKeyLastLon)!;
      fetchTimesByCoordinates(lat, lon);
    } else if (_lastUsedLocationSource == 'address' && _lastUsedCity != null) {
      fetchTimesByAddress(_lastUsedCity!);
    }
  }

  // Deprecated: kept for API stability, no UI should call this anymore
  Future<void> setTimeOffsetMinutes(int minutes) async {
    final clamped = minutes.clamp(-60, 60);
    if (clamped == _timeOffsetMinutes) return;
    _timeOffsetMinutes = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyTimeOffset, _timeOffsetMinutes);
    notifyListeners();
  }

  // New: set per-prayer offset
  Future<void> setPrayerOffset(String prayer, int minutes) async {
    final clamped = minutes.clamp(-60, 60);
    if ((_prayerOffsets[prayer] ?? 0) == clamped) return;
    _prayerOffsets[prayer] = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPerPrayerOffsets, jsonEncode(_prayerOffsets));
    notifyListeners();
  }

  // Notifications master toggle
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    notifyListeners();
  }

  // Per-prayer Adhan toggle
  Future<void> setAdhanEnabled(String prayer, bool enabled) async {
    _adhanEnabled[prayer] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adhan_enabled_${prayer.toLowerCase()}', enabled);
    notifyListeners();
  }

  // Per-prayer Adhan file
  Future<void> setAdhanFile(String prayer, String? fileName) async {
    _adhanFiles[prayer] = fileName;
    final prefs = await SharedPreferences.getInstance();
    if (fileName == null) {
      await prefs.remove('adhan_file_${prayer.toLowerCase()}');
    } else {
      await prefs.setString('adhan_file_${prayer.toLowerCase()}', fileName);
    }
    notifyListeners();
  }

  Future<void> fetchTimesByAddress(String address) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // First, geocode the address to get coordinates
      final geocodingUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(address)}');
      
      final response = await http.get(geocodingUrl, headers: {
        'User-Agent': 'SalatTimeApp/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> locations = json.decode(response.body);
        if (locations.isNotEmpty) {
          final location = locations.first;
          final double lat = double.parse(location['lat']);
          final double lon = double.parse(location['lon']);
          
          // Save the location
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKeyLastSource, 'address');
          await prefs.setString(_prefsKeyLastAddress, address);
          await prefs.setDouble(_prefsKeyLastLat, lat);
          await prefs.setDouble(_prefsKeyLastLon, lon);
          
          _lastUsedLocationSource = 'address';
          _lastUsedCity = address;
          
          // Now fetch prayer times for these coordinates
          await fetchTimesByCoordinates(lat, lon);
          
          // Add to recent locations if not already present
          if (!_recentLocations.contains(address)) {
            _recentLocations.insert(0, address);
            if (_recentLocations.length > 5) {
              _recentLocations.removeLast();
            }
            await prefs.setStringList(_prefsKeyRecentLocations, _recentLocations);
          }
        } else {
          _errorMessage = 'Location not found';
          notifyListeners();
        }
      } else {
        _errorMessage = 'Failed to get location coordinates';
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setCalculationMethod(int method) async {
    if (_calculationMethod != method) {
      _calculationMethod = method;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyCalculationMethod, method);
      
      // Refresh prayer times with new calculation method
      if (_lastUsedLocationSource == 'gps' && _currentPosition != null) {
        await fetchTimesByCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      } else if (_lastUsedLocationSource == 'address' && _lastUsedCity != null) {
        await fetchTimesByAddress(_lastUsedCity!);
      }
      
      notifyListeners();
    }
  }

  Future<void> fetchTimesByCoordinates(double latitude, double longitude) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await http.get(Uri.parse(
          'https://api.aladhan.com/v1/timings/${DateTime.now().toString().split(' ')[0]}?latitude=$latitude&longitude=$longitude&method=$_calculationMethod'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          _prayerTimes = Map<String, dynamic>.from(data['data']['timings']);
          _hijriDateInfo = data['data']['date']['hijri'];
          _gregorianDateInfo = data['data']['date']['gregorian'];
          
          // Save the coordinates
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefsKeyLastSource, 'gps');
          await prefs.setDouble(_prefsKeyLastLat, latitude);
          await prefs.setDouble(_prefsKeyLastLon, longitude);
          
          _lastUsedLocationSource = 'gps';
          _currentPosition = Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          
          // Update next prayer time
          _updateNextPrayer();

          // Schedule alarms for the day (Android)
          try {
            await PrayerTimeScheduler.scheduleForToday(
              latitude: latitude,
              longitude: longitude,
              calculationMethod: _calculationMethod,
              prayerOffsets: _prayerOffsets,
              adhanEnabled: {
                'Fajr': _adhanEnabled['Fajr'] ?? true,
                'Dhuhr': _adhanEnabled['Dhuhr'] ?? true,
                'Asr': _adhanEnabled['Asr'] ?? true,
                'Maghrib': _adhanEnabled['Maghrib'] ?? true,
                'Isha': _adhanEnabled['Isha'] ?? true,
              },
              notificationsEnabled: _notificationsEnabled,
            );
          } catch (_) {}
        } else {
          _errorMessage = 'Failed to get prayer times';
        }
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getPrayerTimesForDate(DateTime date) async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.aladhan.com/v1/timings/${DateFormat('yyyy-MM-dd').format(date)}?latitude=${_currentPosition?.latitude ?? 0}&longitude=${_currentPosition?.longitude ?? 0}&method=$_calculationMethod'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200) {
          return Map<String, dynamic>.from(data['data']['timings']);
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  
  void _updateNextPrayer() {
    _calculateAndSetNextPrayer();
  }
  Future<void> updateImsakVisibility(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyShowImsak, show);
    _showImsak = show;
    notifyListeners();
  }

  Future<void> toggleTimeFormat() async {
    final prefs = await SharedPreferences.getInstance();
    _is24HourFormat = !_is24HourFormat;
    await prefs.setBool(_prefsKeyIs24Hour, _is24HourFormat);
    notifyListeners();
  }

  // TODO: FIX NEXT PRAYER CALCULATION - Widget showing wrong prayer times
  // Current issues:
  // 1. Widget displays Fajr when it should show Asr or other upcoming prayers
  // 2. DateTime.isAfter() comparison may have timing edge cases
  // 3. Prayer time parsing and offset application needs verification
  // 4. Late-night fallback to tomorrow's Fajr logic may be problematic
  // 5. Need consistent timezone handling between this and widget provider
  // 6. Consider adding debug prints to trace exact computation flow
  void _calculateAndSetNextPrayer() {
    _nextPrayerTimer?.cancel();
    if (_prayerTimes == null) {
      _nextPrayerName = null;
      _nextPrayerDateTime = null;
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? nextPrayerTime;
    String? nextPrayerName;

    // Use adjusted times with per-prayer offsets
  // Only consider the five daily prayers for "next" determination
  for (String prayer in const ['Fajr','Dhuhr','Asr','Maghrib','Isha']) {
      final timeStr = _prayerTimes![prayer];
      if (timeStr == null) continue;

      try {
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;

        final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        var prayerTime = today.add(Duration(hours: hour, minutes: minute));
        // apply offset
        final offset = _prayerOffsets[prayer] ?? 0;
        prayerTime = prayerTime.add(Duration(minutes: offset));

        if (prayerTime.isAfter(now)) {
          nextPrayerTime = prayerTime;
          nextPrayerName = prayer;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    // If no prayer found today, next is tomorrow's Fajr
    if (nextPrayerName == null) {
      final fajrStr = _prayerTimes!['Fajr'];
      if (fajrStr != null) {
        try {
          final parts = fajrStr.split(':');
          if (parts.length == 2) {
            final hour = int.parse(parts[0]);
            final minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
            final tomorrow = today.add(const Duration(days: 1));
            var prayerTime = tomorrow.add(Duration(hours: hour, minutes: minute));
            final offset = _prayerOffsets['Fajr'] ?? 0;
            prayerTime = prayerTime.add(Duration(minutes: offset));
            nextPrayerTime = prayerTime;
            nextPrayerName = 'Fajr';
          }
        } catch (e) {
          nextPrayerTime = null;
          nextPrayerName = null;
        }
      }
    }

    final hasChanged = _nextPrayerName != nextPrayerName || _nextPrayerDateTime != nextPrayerTime;

    _nextPrayerName = nextPrayerName;
    _nextPrayerDateTime = nextPrayerTime;

    if (hasChanged) {
      notifyListeners();
      // Debug log
      // ignore: avoid_print
      if (_nextPrayerName != null && _nextPrayerDateTime != null) {
        print('[Provider] Next prayer: $_nextPrayerName at UTC ${_nextPrayerDateTime!.toUtc().toIso8601String()}');
      }
      // Update home widget data when next prayer changes (UTC epoch persisted inside)
      // ignore: unawaited_futures
      WidgetDataService.updateNextPrayerData(this);
    }

    if (_nextPrayerDateTime != null) {
      var timeUntilNext = _nextPrayerDateTime!.difference(now) + const Duration(seconds: 2);
      if (timeUntilNext.isNegative) {
        timeUntilNext = const Duration(seconds: 30);
      }
      _nextPrayerTimer = Timer(timeUntilNext, () async {
        // Foreground fallback: Play Adhan when the next prayer time triggers and show notification
        try {
          if (_notificationsEnabled && _nextPrayerName != null && (_adhanEnabled[_nextPrayerName!] ?? true)) {
            // Show notification first, then play Adhan
            await NotificationService().showAdhanNotification(_nextPrayerName!);
            await AudioService().playAdhanFor(_nextPrayerName!);
          }
        } catch (_) {}
        _calculateAndSetNextPrayer();
      });
    }
  }
}

