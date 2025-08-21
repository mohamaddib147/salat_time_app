import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'splash_screen.dart';
import 'prayer_times_provider.dart';
// Quran imports
import 'quran/quran_provider.dart';
import 'quran/surah_list_screen.dart';
import 'quran/quran_reader_screen.dart';
import 'quran/bookmarks_screen.dart';
import 'quran/search_screen.dart';
import 'quran/quran_audio_provider.dart';
import 'quran/juz_list_screen.dart';
import 'quran/quran_settings_screen.dart';
import 'services/notification_service.dart';
import 'services/prayer_time_scheduler.dart';
import 'theme_provider.dart';
import 'services/widget_data_service.dart';
import 'package:home_widget/home_widget.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized (needed for async before runApp)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services
  await NotificationService().init();
  await PrayerTimeScheduler.initialize();
  
  // Initialize HomeWidget (iOS requires appGroupId configuration during native setup)
  await HomeWidget.setAppGroupId(WidgetDataService.appGroupId);
  
  // Schedule periodic widget refresh using alarm manager
  await PrayerTimeScheduler.scheduleWidgetRefresh();
  
  runApp(const PrayerGuideApp());
}

class PrayerGuideApp extends StatelessWidget {
  const PrayerGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerTimesProvider()),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
  ChangeNotifierProvider(create: (_) => QuranAudioProvider()),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
        title: 'Prayer Guide',
        themeMode: theme.themeMode,
        theme: theme.lightTheme,
        darkTheme: theme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/quran_list': (_) => const SurahListScreen(),
          '/bookmarks': (_) => const BookmarksScreen(),
          '/qsearch': (_) => const SearchScreen(),
          '/juz': (_) => const JuzListScreen(),
          '/quran_settings': (_) => const QuranSettingsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/quran_reader') {
            final start = settings.arguments is int ? settings.arguments as int : 1;
            return MaterialPageRoute(
              builder: (context) {
                final provider = Provider.of<QuranProvider>(context, listen: false);
                return ChangeNotifierProvider.value(
                  value: provider,
                  child: QuranReaderScreen(startPage: start),
                );
              },
            );
          }
          return null;
        },
      ),
      ),
    );
  }
}