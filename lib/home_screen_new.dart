import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'prayer_times_provider.dart';
import 'calendar_page.dart';
import 'settings_screen.dart';
import 'quran/surah_list_screen.dart';
import 'services/audio_service.dart';
import 'services/permission_service.dart';
import 'services/prayer_time_scheduler.dart';
import 'services/widget_data_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late HijriCalendar _hijriDate;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _hijriDate = HijriCalendar.now();
    _initPrayerTimes();
  }

  void _initPrayerTimes() async {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    await provider.fetchTimesByGps();
  }

  Future<void> _checkPermissions() async {
    final permissions = await PermissionService().checkAllPermissions();
    final hasNotification = permissions['notification'] ?? false;

    String status = hasNotification ? 'All permissions granted ✓' : 'Missing permissions ❌';
    String details = 'Notifications: ${hasNotification ? 'Granted' : 'Denied'}';

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Status'),
        content: Text('$status\n\n$details'),
        actions: [
          if (!hasNotification)
            TextButton(
              child: const Text('Request Permissions'),
              onPressed: () {
                Navigator.of(context).pop();
                PermissionService().requestAllPermissions(context);
              },
            ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Prayer Times' : 'Quran'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.green[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: _tab == 0
            ? [
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'update_widget') {
                      final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
                      try {
                        await WidgetDataService.updateNextPrayerData(provider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Widget updated successfully')),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to update widget')),
                        );
                      }
                    } else if (v == 'check_permissions') {
                      await _checkPermissions();
                    } else if (v == 'test_adhan') {
                      // Ensure permissions
                      final ok = await PermissionService().requestAllPermissions(context);
                      if (!ok) return;
                      // Schedule a background test alarm in 1 minute for current/next prayer
                      final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
                      final next = provider.nextPrayerName ?? 'Asr';
                      await PrayerTimeScheduler.scheduleTestAlarm(delay: const Duration(minutes: 1), prayerName: next);
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Scheduled test Adhan for $next in 1 minute')),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'check_permissions', child: Text('Check Permissions')),
                    PopupMenuItem(value: 'test_adhan', child: Text('Test Adhan (1 min)')),
                    PopupMenuItem(value: 'update_widget', child: Text('Update Home Widget')),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CalendarPage()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                  },
                ),
              ]
            : [],
      ),
      body: _tab == 0 ? _buildPrayerTab() : const SurahListScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Prayer'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Quran'),
        ],
      ),
    );
  }

  Widget _buildPrayerTab() {
    return Column(
      children: [
        _buildDateHeader(),
        // Date selector timeline
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: EasyDateTimeLine(
            initialDate: _selectedDate,
            onDateChange: (date) {
              setState(() {
                _selectedDate = date;
                _hijriDate = HijriCalendar.fromDate(date);
              });
            },
          ),
        ),
        Expanded(
          child: _buildPrayerTimesList(),
        ),
      ],
    );
  }

  Widget _buildDateHeader() {
    final now = _selectedDate;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(now),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${_hijriDate.toFormat("dd MMMM yyyy")} AH',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesList() {
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: provider.getPrayerTimesForDate(_selectedDate),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load prayer times',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data;
            if (data == null) {
              return Center(child: Text('No prayer times available'));
            }

            // Only 5 daily prayers in order
            final ordered = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
            final filtered = <String, String>{
              for (final k in ordered)
                if (data.containsKey(k)) k: data[k].toString(),
            };

            return ListView(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: filtered.entries.map((entry) {
                final isCurrentPrayer = _isCurrentPrayer(entry.key, entry.value, filtered, provider);
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  elevation: isCurrentPrayer ? 4 : 1,
                  child: ListTile(
                    leading: Icon(
                      _getPrayerIcon(entry.key),
                      color: isCurrentPrayer ? Colors.teal : Colors.grey[600],
                    ),
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: isCurrentPrayer ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentPrayer ? Colors.teal[700] : Colors.black87,
                      ),
                    ),
                    trailing: ValueListenableBuilder<bool>(
                      valueListenable: AudioService().isPlaying,
                      builder: (context, playing, _) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: AudioService().currentPrayer,
                          builder: (context, current, __) {
                            final isThisPlaying = playing && current == entry.key;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.formatTime(entry.value, prayerName: entry.key),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: isCurrentPrayer ? FontWeight.bold : FontWeight.w500,
                                    color: isCurrentPrayer ? Colors.teal[700] : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: isThisPlaying ? 'Stop Adhan' : 'Play Adhan',
                                  icon: Icon(isThisPlaying ? Icons.stop_circle_outlined : Icons.play_arrow, color: Colors.teal),
                                  onPressed: () async {
                                    await AudioService().togglePlayFor(entry.key);
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  bool _isCurrentPrayer(String prayerName, String prayerTime, Map<String, String> allTimes, PrayerTimesProvider provider) {
    try {
      final now = DateFormat('HH:mm').format(DateTime.now());
      final current = _convertToMinutes(now);

      // build adjusted timeline using per-prayer offsets
      final keys = allTimes.keys.toList();
      final timesAdjusted = keys
          .map((k) => _wrapMinutes(_convertToMinutes(allTimes[k]!) + provider.getOffsetFor(k)))
          .toList();

      final adjustedThis = _wrapMinutes(_convertToMinutes(prayerTime) + provider.getOffsetFor(prayerName));
      final idx = keys.indexOf(prayerName);
      if (idx == -1) return false;

      final nextTime = idx < timesAdjusted.length - 1
          ? timesAdjusted[idx + 1]
          : _wrapMinutes(_convertToMinutes('23:59'));

      return current >= adjustedThis && current < nextTime;
    } catch (_) {
      return false;
    }
  }

  int _wrapMinutes(int m) {
    const day = 24 * 60;
    int r = m % day;
    return r < 0 ? r + day : r;
  }

  int _convertToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return 0;
      return int.parse(parts[0].trim()) * 60 + int.parse(parts[1].trim());
    } catch (_) {
      return 0;
    }
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return Icons.brightness_2;
      case 'sunrise':
        return Icons.wb_sunny_outlined;
      case 'dhuhr':
        return Icons.sunny;
      case 'asr':
        return Icons.sunny_snowing;
      case 'maghrib':
        return Icons.nights_stay_outlined;
      case 'isha':
        return Icons.dark_mode;
      case 'imsak':
        return Icons.access_time;
      default:
        return Icons.access_time;
    }
  }
}
