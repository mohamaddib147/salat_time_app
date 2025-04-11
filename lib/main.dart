import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import 'splash_screen.dart';
import 'prayer_times_provider.dart'; // Import your provider class

void main() {
  // Ensure Flutter bindings are initialized (needed for async before runApp)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PrayerGuideApp());
}

class PrayerGuideApp extends StatelessWidget {
  const PrayerGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the entire app with ChangeNotifierProvider
    return ChangeNotifierProvider(
      create: (context) => PrayerTimesProvider(), // Create an instance of your provider
      child: MaterialApp(
        title: 'Prayer Guide',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      ),
    );
  }
}