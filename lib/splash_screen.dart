import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen_new.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() {
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- Background ---
      backgroundColor: Colors.green[800], // Darker green background

      // --- Content ---
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- App Name with Shadow ---
            Text(
              'Salat Time', // Updated App Name
              style: TextStyle(
                fontSize: 42.0, // Slightly larger
                fontWeight: FontWeight.bold,
                color: Colors.white,
                // --- Adding Shadow ---
                shadows: [
                  Shadow(
                    blurRadius: 10.0, // How much the shadow spreads
                    color: Colors.black.withOpacity(0.5), // Shadow color
                    offset: const Offset(4.0, 4.0), // Shadow position (horizontal, vertical)
                  ),
                ],
                // fontFamily: 'YourCustomFont', // Consider adding a nice font later
              ),
            ),
            const SizedBox(height: 30), // Increased spacing
            // Optional: Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
              strokeWidth: 3.0,
            ),
          ],
        ),
      ),
    );
  }
}