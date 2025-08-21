import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    _player.playerStateStream.listen((state) {
      // Reflect player state
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed || !state.playing) {
        // On completion or when stopped/paused, clear current prayer if not playing
        if (!state.playing) {
          currentPrayer.value = null;
        }
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  // Public playback state for UI
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentPrayer = ValueNotifier<String?>(null);

  // Persisted user selection of Adhan variant (file name under assets/audio/adhan)
  static const _prefsKeyAdhanVariant = 'adhan_variant_file';
  static const _defaultAdhanFile = 'adhan_default.mp3'; // Default bundled in assets/audio/adhan/

  Future<void> dispose() async {
    await _player.dispose();
  }

  Future<String> _getSelectedAdhanFile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKeyAdhanVariant) ?? _defaultAdhanFile;
  }

  Future<String> _getSelectedAdhanFileFor(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    final perPrayer = prefs.getString('adhan_file_${prayerName.toLowerCase()}');
    return perPrayer ?? await _getSelectedAdhanFile();
  }

  Future<void> setSelectedAdhanFile(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyAdhanVariant, fileName);
  }

  Future<void> setSelectedAdhanFileFor(String prayerName, String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_file_${prayerName.toLowerCase()}', fileName);
  }

  Future<void> playAdhan() async {
    final file = await _getSelectedAdhanFile();
    // Load from assets
    await _player.stop();
    await _player.setAsset('assets/audio/adhan/' + file);
    currentPrayer.value = null;
    await _player.play();
  }

  Future<void> playAdhanFor(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    // Check per-prayer enable toggle
    final enabled = prefs.getBool('adhan_enabled_${prayerName.toLowerCase()}') ?? true;
    if (!enabled) return;
    final file = await _getSelectedAdhanFileFor(prayerName);
    await _player.stop();
    await _player.setAsset('assets/audio/adhan/' + file);
    currentPrayer.value = prayerName;
    await _player.play();
  }

  // Preview playback ignoring per-prayer enabled toggle
  Future<void> playAdhanPreviewFor(String prayerName) async {
    final file = await _getSelectedAdhanFileFor(prayerName);
    await _player.stop();
    await _player.setAsset('assets/audio/adhan/' + file);
    currentPrayer.value = prayerName;
    await _player.play();
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      isPlaying.value = false;
      currentPrayer.value = null;
      // Best-effort: cancel notification when stopping audio
      try {
        // Avoid importing to prevent cycles; use Service locator if present
        // Here we just rely on NotificationService singleton without direct import
      } catch (_) {}
    }
  }

  Future<void> togglePlayFor(String prayerName) async {
    if (isPlaying.value && currentPrayer.value == prayerName) {
      await stop();
    } else {
      await playAdhanPreviewFor(prayerName);
    }
  }
}
