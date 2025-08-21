import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_provider.dart';
import 'theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showImsak = false;
  final TextEditingController _locationController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showImsak = prefs.getBool('show_imsak') ?? false;
    });
  }

  Future<void> _toggleImsak(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_imsak', value);
    setState(() {
      _showImsak = value;
    });
    
    // Notify the provider to update the main screen
    if (mounted) {
      Provider.of<PrayerTimesProvider>(context, listen: false)
          .updateImsakVisibility(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.green[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        children: [
          // App Theme Settings
          _buildSection(
            title: 'Appearance',
            children: [
              Consumer<AppThemeProvider>(
                builder: (context, theme, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                          ],
                          selected: {theme.themeMode},
                          onSelectionChanged: (set) {
                            final m = set.first;
                            theme.setThemeMode(m);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          // Location Settings
          _buildSection(
            title: 'Location',
            children: [
              ListTile(
                leading: Icon(Icons.location_on),
                title: Text('Use GPS Location'),
                trailing: IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    Provider.of<PrayerTimesProvider>(context, listen: false)
                        .fetchTimesByGps();
                    Navigator.pop(context);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'City Name',
                    hintText: 'Enter city name',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () {
                        if (_locationController.text.isNotEmpty) {
                          Provider.of<PrayerTimesProvider>(context, listen: false)
                              .fetchTimesByAddress(_locationController.text);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Prayer Times Settings
          _buildSection(
            title: 'Prayer Times',
            children: [
              SwitchListTile(
                title: Text('Show Imsak Time'),
                subtitle: Text('Display Imsak time on the main screen'),
                value: _showImsak,
                onChanged: _toggleImsak,
              ),
              const Divider(),
              Consumer<PrayerTimesProvider>(
                builder: (context, provider, _) {
                  return SwitchListTile(
                    title: const Text('Adhan Notifications'),
                    subtitle: const Text('Play Adhan and show notifications at prayer times'),
                    value: provider.notificationsEnabled,
                    onChanged: (v) async {
                      await provider.setNotificationsEnabled(v);
                    },
                  );
                },
              ),
              Consumer<PrayerTimesProvider>(
                builder: (context, provider, _) {
                  final adhanFiles = <String>[
                    'adhan_default.mp3',
                    'adhan_fajr_zahrani.mp3',
                    'adhan_madinah_archive.mp3',
                    'adhan_makkah.mp3',
                    'adhan_turkey.mp3',
                  ];

                  Widget perPrayer(String p) {
                    final enabled = provider.getAdhanEnabled(p);
                    final currentFile = provider.getAdhanFile(p);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Row(
                        children: [
                          SizedBox(width: 70, child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Switch(
                            value: enabled,
                            onChanged: (v) => provider.setAdhanEnabled(p, v),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: IgnorePointer(
                              ignoring: !enabled,
                              child: Opacity(
                                opacity: enabled ? 1.0 : 0.5,
                                child: DropdownButtonFormField<String>(
                                  value: currentFile ?? 'adhan_default.mp3',
                                  isExpanded: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Adhan file'),
                                  items: adhanFiles
                                      .map((f) => DropdownMenuItem<String>(value: f, child: Text(f)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) provider.setAdhanFile(p, v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text('Per‑Prayer Adhan', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      perPrayer('Fajr'),
                      perPrayer('Dhuhr'),
                      perPrayer('Asr'),
                      perPrayer('Maghrib'),
                      perPrayer('Isha'),
                    ],
                  );

                  return AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: details,
                    crossFadeState: provider.notificationsEnabled
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  );
                },
              ),
              Consumer<PrayerTimesProvider>(
                builder: (context, provider, _) {
                  final methods = provider.availableCalculationMethods;
                  final current = provider.calculationMethod;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Calculation Method', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: current,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: methods.entries
                              .map((e) => DropdownMenuItem<int>(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              provider.setCalculationMethod(val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Text('Per-Prayer Time Offsets (minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _offsetRow(context, provider, 'Fajr'),
                        _offsetRow(context, provider, 'Dhuhr'),
                        _offsetRow(context, provider, 'Asr'),
                        _offsetRow(context, provider, 'Maghrib'),
                        _offsetRow(context, provider, 'Isha'),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          // Display Settings
          _buildSection(
            title: 'Display',
            children: [
              Consumer<PrayerTimesProvider>(
                builder: (context, provider, child) {
                  return SwitchListTile(
                    title: Text('24-Hour Format'),
                    value: provider.is24HourFormat,
                    onChanged: (value) {
                      provider.toggleTimeFormat();
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offsetRow(BuildContext context, PrayerTimesProvider provider, String prayer) {
    final value = provider.getOffsetFor(prayer);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(prayer, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.teal[700])),
          ),
          IconButton(
            icon: Icon(Icons.remove_circle_outline),
            onPressed: () => provider.setPrayerOffset(prayer, value - 1),
          ),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: value.toString(),
              key: ValueKey('$prayer-$value'),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onFieldSubmitted: (v) {
                final n = int.tryParse(v) ?? 0;
                provider.setPrayerOffset(prayer, n);
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => provider.setPrayerOffset(prayer, value + 1),
          ),
          const SizedBox(width: 8),
          Text('(-60 .. +60)', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.teal[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        Divider(),
      ],
    );
  }
}
