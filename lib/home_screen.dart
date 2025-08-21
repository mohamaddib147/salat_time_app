import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter/services.dart';
import 'prayer_times_provider.dart';
import 'services/audio_service.dart';
import 'services/widget_data_service.dart';
import 'services/prayer_time_scheduler.dart';
import 'services/permission_service.dart';
import 'calendar_page.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HijriCalendar _hijriDate;

  @override
  void initState() {
    super.initState();
    _hijriDate = HijriCalendar.now();
    _initPrayerTimes();
  }

  void _initPrayerTimes() async {
    // Request permissions first
    await PermissionService().requestAllPermissions(context);
    
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    await provider.fetchTimesByGps();
  }

  Future<void> _refreshPrayerTimes() async {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    await provider.fetchTimesByGps();
  }

  Future<void> _checkPermissions() async {
    final permissions = await PermissionService().checkAllPermissions();
    final hasNotification = permissions['notification'] ?? false;
    
    String status = hasNotification ? 'All permissions granted ✓' : 'Missing permissions ❌';
    String details = 'Notifications: ${hasNotification ? 'Granted' : 'Denied'}';
    
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

  // Removed: _testAdhanSystem (replaced with scheduled alarm test)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prayer Times'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.green[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Permission status indicator
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: Colors.white,
            ),
            onPressed: () => _checkPermissions(),
            tooltip: 'Check Permissions',
          ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Scheduled test Adhan for $next in 1 minute')), 
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'check_permissions', child: Text('Check Permissions')),
              const PopupMenuItem(value: 'test_adhan', child: Text('Test Adhan (1 min)')),
              const PopupMenuItem(value: 'update_widget', child: Text('Update Home Widget')),
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
        ],
      ),
      body: Column(
        children: [
          _buildDateHeader(),
          Expanded(
            child: _buildPrayerTimesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
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
        if (provider.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          );
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
                TextButton(
                  onPressed: _initPrayerTimes,
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.prayerTimes == null) {
          return Center(
            child: Text('No prayer times available'),
          );
        }

        // Only show the 5 daily prayers in order
        final ordered = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
        final filteredTimes = <String, String>{
          for (final k in ordered)
            if (provider.prayerTimes!.containsKey(k)) k: provider.prayerTimes![k].toString()
        };

        final currentPrayer = _currentPrayer(filteredTimes);

        return RefreshIndicator(
          onRefresh: _refreshPrayerTimes,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const AlwaysScrollableScrollPhysics(),
            children: filteredTimes.entries.map((entry) {
              final isCurrent = entry.key == currentPrayer;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                elevation: isCurrent ? 4 : 1,
                child: ListTile(
                  leading: Icon(
                    _getPrayerIcon(entry.key),
                    color: isCurrent ? Colors.teal : Colors.grey[600],
                  ),
                  title: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.teal[700] : Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          provider.formatTime(entry.value),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? Colors.teal[700] : Colors.black87,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.teal.withOpacity(0.7)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: ValueListenableBuilder<bool>(
                            valueListenable: AudioService().isPlaying,
                            builder: (context, isPlaying, _) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: AudioService().currentPrayer,
                                builder: (context, currentPrayer, _) {
                                  final isPlayingThis = isPlaying && currentPrayer == entry.key;
                                  return Icon(
                                    isPlayingThis ? Icons.stop : Icons.play_arrow,
                                    color: Colors.teal,
                                    size: 18,
                                  );
                                },
                              );
                            },
                          ),
                          label: ValueListenableBuilder<bool>(
                            valueListenable: AudioService().isPlaying,
                            builder: (context, isPlaying, _) {
                              return ValueListenableBuilder<String?>(
                                valueListenable: AudioService().currentPrayer,
                                builder: (context, currentPrayer, _) {
                                  final isPlayingThis = isPlaying && currentPrayer == entry.key;
                                  return Text(
                                    isPlayingThis ? 'Stop' : 'Test',
                                    style: const TextStyle(color: Colors.teal),
                                  );
                                },
                              );
                            },
                          ),
                          onPressed: () async {
                            try {
                              // Light haptic for feedback
                              await HapticFeedback.selectionClick();

                              // Play/stop preview without blocking on notification permission
                              await AudioService().togglePlayFor(entry.key);

                              // Non-blocking tip about notifications (for background alarms)
                              final hasPermission = await PermissionService().isNotificationPermissionGranted();
                              if (!hasPermission) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Tip: Enable notifications to get Adhan at prayer time'),
                                    action: SnackBarAction(
                                      label: 'Enable',
                                      onPressed: () => PermissionService().requestAllPermissions(context),
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Testing Adhan for ${entry.key}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error playing Adhan: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  onTap: () async {
                    try {
                      await AudioService().playAdhanPreviewFor(entry.key);
                    } catch (_) {}
                  },
                  onLongPress: () async {
                    try {
                      await AudioService().playAdhanPreviewFor(entry.key);
                    } catch (_) {}
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String? _currentPrayer(Map<String, String> times) {
  final order = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final now = DateTime.now();
    String? lastName;
    String? nextName;
    for (final name in order) {
      final t = times[name];
      if (t == null) continue;
      final dt = _parsePrayerTime(t);
      if (dt == null) continue;
      if (dt.isBefore(now) || dt.isAtSameMomentAs(now)) {
        lastName = name;
      } else {
        nextName ??= name;
      }
    }
    return lastName ?? nextName ?? (times.keys.isNotEmpty
        ? order.firstWhere((e) => times.containsKey(e), orElse: () => times.keys.first)
        : null);
  }

  DateTime? _parsePrayerTime(String value) {
    final now = DateTime.now();
    // Try HH:mm
    try {
      final parts = value.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return DateTime(now.year, now.month, now.day, h, m);
      }
    } catch (_) {}
    // Try h:mm a
    try {
      final fmt = DateFormat('h:mm a');
      final t = fmt.parse(value);
      return DateTime(now.year, now.month, now.day, t.hour, t.minute);
    } catch (_) {}
    return null;
  }

  IconData _getPrayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight_outlined;
      case 'dhuhr':
        return Icons.wb_sunny_outlined;
      case 'asr':
        return Icons.schedule_outlined;
      case 'maghrib':
        return Icons.nightlight_outlined;
      case 'isha':
        return Icons.dark_mode_outlined;
      default:
        return Icons.access_time;
    }
  }
}
