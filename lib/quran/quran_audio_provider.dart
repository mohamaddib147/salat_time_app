import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:quran/quran.dart' as quran;

class QuranAudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isPaused = false;
  int? _currentSurah;
  int? _currentAyah;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  int? get currentSurah => _currentSurah;
  int? get currentAyah => _currentAyah;
  Duration get position => _position;
  Duration get duration => _duration;

  QuranAudioProvider() {
    _player.onPlayerComplete.listen((event) {
      // Auto-advance to next ayah in the same surah
      if (_currentSurah != null && _currentAyah != null) {
        final s = _currentSurah!;
        final nextAyah = _currentAyah! + 1;
        final count = quran.getVerseCount(s);
        if (nextAyah <= count) {
          playAyah(s, nextAyah);
        } else {
          // End of surah
          _isPlaying = false;
          _isPaused = false;
          notifyListeners();
        }
      } else {
        _isPlaying = false;
        _isPaused = false;
        notifyListeners();
      }
    });

    _player.onPositionChanged.listen((d) {
      _position = d;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
  }

  Future<void> playSurah(int surah) async {
    // Play entire surah audio URL
    final url = quran.getAudioURLBySurah(surah);
    _currentSurah = surah;
    _currentAyah = null;
    _isPlaying = true;
    _isPaused = false;
    _position = Duration.zero;
    notifyListeners();
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> playAyah(int surah, int ayah) async {
    final url = quran.getAudioURLByVerse(surah, ayah);
    _currentSurah = surah;
    _currentAyah = ayah;
    _isPlaying = true;
    _isPaused = false;
    _position = Duration.zero;
    notifyListeners();
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    _isPaused = true;
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.resume();
    _isPlaying = true;
    _isPaused = false;
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _isPaused = false;
    notifyListeners();
  }

  Future<void> stopAndClear() async {
    await stop();
    _currentSurah = null;
    _currentAyah = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> nextAyah() async {
    if (_currentSurah == null || _currentAyah == null) return;
    final s = _currentSurah!;
    final next = _currentAyah! + 1;
    final count = quran.getVerseCount(s);
    if (next <= count) {
      await playAyah(s, next);
    } else {
      // End of surah: stop
      await stop();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
