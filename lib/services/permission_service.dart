import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request all necessary permissions for Adhan and notifications
  Future<bool> requestAllPermissions(BuildContext context) async {
    bool allGranted = true;

    // Request notification permission (Android 13+)
    if (Platform.isAndroid) {
      final notificationStatus = await Permission.notification.request();
      if (notificationStatus != PermissionStatus.granted) {
        allGranted = false;
        _showPermissionDialog(
          context,
          'Notification Permission Required',
          'This app needs notification permission to alert you for prayer times.',
          () => openAppSettings(),
        );
      }
    }

    return allGranted;
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true; // iOS handles this automatically
  }

  /// Show permission dialog
  void _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onOpenSettings,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                onOpenSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show exact alarm permission dialog (Android 12+)
  Future<void> showExactAlarmDialog(BuildContext context) async {
    if (!Platform.isAndroid) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exact Alarm Permission'),
          content: const Text(
            'For accurate prayer time notifications, please allow this app to schedule exact alarms in the system settings.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Check all required permissions status
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'notification': await isNotificationPermissionGranted(),
      // Add other permission checks here if needed
    };
  }
}
