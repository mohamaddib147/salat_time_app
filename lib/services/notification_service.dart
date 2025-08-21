import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'audio_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Background handler for notification actions, taps, and dismissals
  try {
    // Stop Adhan on any interaction: tap, action button, or dismissal
    if (response.actionId == 'STOP_ADHAN' ||
        response.notificationResponseType == NotificationResponseType.selectedNotification ||
        response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
      AudioService().stop();
    }
  } catch (e) {
    // Silent fail in background
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
  onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) async {
    // Foreground handler for notification interactions
    try {
      // Stop Adhan on any interaction: tap, action button, or dismissal
      if (response.actionId == 'STOP_ADHAN' ||
          response.notificationResponseType == NotificationResponseType.selectedNotification ||
          response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
        await AudioService().stop();
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> showAdhanNotification(String prayerName) async {
    const androidDetails = AndroidNotificationDetails(
      'adhan_channel',
      'Adhan Notifications',
      channelDescription: 'Alerts for prayer times with Adhan playback',
      importance: Importance.max,
      priority: Priority.high,
  playSound: false, // We handle audio separately
  enableVibration: true,
  ongoing: true, // Keep visible; swipe disabled so Stop action controls stop
  autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'STOP_ADHAN',
          'Stop Adhan',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      1001, // Fixed ID for Adhan notifications
      'Time for Prayer',
      'It\'s time for $prayerName prayer',
      details,
    );
  }

}
