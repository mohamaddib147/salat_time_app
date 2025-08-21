# Salat Time - Prayer Times Flutter App

A polished Flutter app that shows accurate daily prayer (Salat) times, plays Adhan at prayer time with a notification, and provides a home screen widget with the next prayer and countdown. Fetch times by GPS or manual city input.

**(Optional: Add Screenshots Here)**
<!-- ![Screenshot 1](link/to/screenshot1.png) -->
<!-- ![Screenshot 2](link/to/screenshot2.png) -->

---

## Features

Current highlights:

*   Splash screen
*   Automatic GPS and manual city lookup
*   Daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) with per‑prayer time offsets
*   Time format toggle (12/24h)
*   Home screen widget: next prayer name + live countdown (updates every minute)
*   Adhan at prayer time in the background via exact alarms (Android)
*   High‑importance notification with STOP action when Adhan plays
*   In‑app actions: Check Permissions, Test Adhan (1 min), Update Home Widget
*   Per‑prayer Adhan enable/disable and audio selection; preview Test per prayer
*   UTC‑based time handling for reliable next‑prayer logic across DST/timezones
*   Provider state management with persistence (`shared_preferences`)

## Future Enhancements (Potential Ideas)

*   Qibla Direction Compass
*   iOS widget extension
*   Battery optimization and exact‑alarm deep links per OEM
*   Offline caching of monthly prayer times
*   More settings: Asr juristic method, advanced notification options

---

## Technology Stack & Key Dependencies

*   Framework: Flutter
*   Language: Dart
*   State: [`provider`](https://pub.dev/packages/provider)
*   Location: [`geolocator`](https://pub.dev/packages/geolocator)
*   Networking: [`http`](https://pub.dev/packages/http)
*   Persistence: [`shared_preferences`](https://pub.dev/packages/shared_preferences)
*   Date/Time: [`intl`](https://pub.dev/packages/intl)
*   Audio: [`just_audio`](https://pub.dev/packages/just_audio) (Adhan), [`audioplayers`](https://pub.dev/packages/audioplayers) (Quran)
*   Notifications: [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
*   Scheduling: [`android_alarm_manager_plus`](https://pub.dev/packages/android_alarm_manager_plus)
*   Home widget bridge: [`home_widget`](https://pub.dev/packages/home_widget)
*   Permissions: [`permission_handler`](https://pub.dev/packages/permission_handler)

---

## Project Structure

The project follows a standard Flutter structure:
salat_time/
├── android/ # Android platform-specific files
├── ios/ # iOS platform-specific files
├── lib/ # Main Dart code for the application
│ ├── main.dart # App entry point, MaterialApp setup, Provider setup
│ ├── splash_screen.dart # Implements the splash screen UI and navigation logic
│ ├── home_screen.dart # Main prayer UI with actions (Test Adhan, Check Permissions, Update Widget)
│ ├── home_screen_new.dart # Alternative tabbed Home (Prayer/Quran)
│ └── prayer_times_provider.dart # State management, business logic, API calls
│ └── services/ # Audio, notifications, scheduling, widget data, permissions
├── test/ # Unit and widget tests (if any)
├── pubspec.yaml # Project metadata and dependencies
└── README.md # This file



---

## Key Files & Classes Breakdown

### `lib/main.dart`

*   **Purpose:** The entry point of the Flutter application.
*   **Key Components:**
    *   `main()`: Runs the application by calling `runApp()`. Ensures `WidgetsFlutterBinding.ensureInitialized()`.
    *   `SalatTimeApp` (StatelessWidget): The root widget of the application.
    *   `MaterialApp`: Configures the overall app theme, title, initial route, and disables the debug banner.
    *   `ChangeNotifierProvider`: Wraps the `MaterialApp` to provide the `PrayerTimesProvider` instance to the entire widget tree below it. This makes the application state accessible anywhere needed.

### `lib/splash_screen.dart`

*   **Purpose:** Displays a branded loading screen when the app starts.
*   **Key Components:**
    *   `SplashScreen` (StatefulWidget): Needed to use `initState` for the timer.
    *   `_SplashScreenState`:
        *   `initState()`: Starts a `Timer` when the widget is first built.
        *   `_navigateToHome()`: Uses a `Timer` to wait for a few seconds (e.g., 3 seconds) and then navigates to the `HomeScreen` using `Navigator.pushReplacement`. `pushReplacement` ensures the user cannot navigate back to the splash screen.
        *   `build()`: Defines the UI, typically showing the app name (`Salat Time`) with styling (background color, text style with shadow) and a `CircularProgressIndicator`.

### `lib/home_screen.dart`

*   **Purpose:** The main screen where users interact with the app. Displays location input, recent searches, prayer times, and provides action buttons.
*   **Key Components:**
    *   `HomeScreen` (StatefulWidget): Manages the `TextEditingController` for the manual location input.
    *   `_HomeScreenState`:
        *   `_locationController`: Controls the manual location `TextField`.
        *   `dispose()`: Disposes the `_locationController` when the widget is removed.
        *   `_searchManualLocation()`: Triggered by the search button or text field submission. Parses input, calls `provider.fetchTimesByCity()`, and handles keyboard dismissal/empty field checks.
        *   `build()`: Constructs the main UI using `Scaffold`, `AppBar`, `Padding`, `Column`, `TextField`, `IconButton`, `TextButton`, `ListView`, etc.
            *   **AppBar:** Contains the app title and action buttons (time format toggle, GPS refresh). Buttons use `Provider.of<PrayerTimesProvider>(context, listen: false)` to trigger actions in the provider without rebuilding the entire `HomeScreen`.
            *   **Body:** Includes sections for manual input (`_buildManualLocationInput`), recent locations (`_buildRecentLocations`), a divider, and the main display area (`_buildPrayerTimesDisplay`).
        *   `_buildManualLocationInput()`: Returns the styled `TextField` and search button row.
        *   `_buildRecentLocations()`: Uses a `Consumer<PrayerTimesProvider>` to reactively display `ActionChip` widgets for recent searches. Tapping a chip populates the input field and triggers a search.
        *   `_buildPrayerTimesDisplay()`: Uses `Provider.of<PrayerTimesProvider>(context)` (or a `Consumer`) to check the provider's state (`isLoading`, `errorMessage`, `prayerTimes`). It conditionally renders:
            *   A loading indicator.
            *   An error message with a retry button.
            *   An initial prompt message.
            *   The location info, the secondary time format toggle button, and the `ListView` of prayer times (using `_buildPrayerTimeRow`). Uses `Expanded` to ensure the `ListView` scrolls correctly.
        *   `_buildPrayerTimeRow()`: Helper widget to display a single prayer time entry (Name + Formatted Time) within a styled `Card`. Uses `provider.formatTime()` for display.

### `lib/prayer_times_provider.dart`

*   **Purpose:** The core state management and logic class. It handles fetching data, managing state variables, interacting with storage, and notifying listeners about changes. Acts as the "ViewModel" or "Bloc" in this architecture.
*   **Key Components:**
    *   `PrayerTimesProvider` (extends `ChangeNotifier`): Allows widgets to listen for changes using `notifyListeners()`.
    *   **State Variables:** `_currentPosition`, `_prayerTimes`, `_errorMessage`, `_isLoading`, `_recentLocations`, `_is24HourFormat`, `_calculationMethod`, `_lastUsedLocationSource`, `_lastUsedCity`. These hold the application's data and UI state.
    *   **Getters:** Publicly expose the state variables.
    *   **Constructor:** Calls `_loadPreferences()` to initialize state from storage.
    *   **Persistence Methods:**
        *   `_loadPreferences()`: Reads data (`recentLocations`, `is24HourFormat`, `calculationMethod`) from `SharedPreferences`.
        *   `_saveRecentLocation()`: Updates the `_recentLocations` list and saves it back to `SharedPreferences`.
        *   `toggleTimeFormat()`: Toggles `_is24HourFormat` and saves the new value.
        *   `setCalculationMethod()`: Updates `_calculationMethod` and saves (example for future settings).
    *   **Core Logic Methods:**
        *   `fetchTimesByGps()`: Handles the entire flow for getting GPS location (permissions, service check, `geolocator.getCurrentPosition()`) and then calls `_fetchPrayerTimes` with coordinates. Manages loading/error states.
        *   `fetchTimesByCity()`: Handles manual input flow. Calls `_fetchPrayerTimes` with city/country, saves recent location on success. Manages loading/error states.
        *   `_fetchPrayerTimes()`: The central API calling method. Takes either coordinates or city/country. Constructs the appropriate Al Adhan API URL (using `Uri.https` and ensuring date format for city lookups). Makes the `http.get` request. Parses the JSON response. Updates `_prayerTimes` or `_errorMessage`. Includes specific error handling for API responses (e.g., city not found, 400/404 status codes).
        *   `refetchLastUsedLocation()`: Attempts to refresh data based on whether GPS or Manual search was last successful.
    *   `formatTime()`: Helper method using `intl` package to format a 24-hour time string (`HH:mm`) into either 12-hour (`h:mm a`) or 24-hour format based on the `_is24HourFormat` flag.
    *   `notifyListeners()`: Called whenever state changes that the UI needs to react to.

### Background Adhan, Notifications, and Widget

* `lib/services/prayer_time_scheduler.dart`: Schedules exact alarms for the five daily prayers and periodic widget refresh; background callback shows a high‑importance notification (with STOP action) then plays Adhan.
* `lib/services/notification_service.dart`: Initializes and displays notifications; handles STOP action in foreground/background.
* `lib/services/audio_service.dart`: Plays Adhan audio (per‑prayer enable and file selection); inline preview for Test buttons.
* `lib/services/widget_data_service.dart`: Computes next prayer and persists UTC epoch/name/countdown for the widget; standardizes on UTC for reliability.
* `android/app/src/main/java/.../NextPrayerWidgetProvider.java`: Android widget provider rendering and minute‑tick updates; reads saved UTC epoch and shows a live countdown.

---

## State Management Approach

This project uses the **`provider` package** for state management, specifically the `ChangeNotifier` and `ChangeNotifierProvider` pattern.

1.  **`PrayerTimesProvider`:** A class that `extends ChangeNotifier`. It holds the application state (prayer times, loading status, errors, user preferences) and contains the business logic (fetching location, calling API, saving preferences).
2.  **`notifyListeners()`:** When data or state changes within `PrayerTimesProvider` (e.g., after an API call completes or a preference is toggled), `notifyListeners()` is called.
3.  **`ChangeNotifierProvider`:** In `main.dart`, the entire `MaterialApp` is wrapped in `ChangeNotifierProvider<PrayerTimesProvider>`. This creates an instance of `PrayerTimesProvider` and makes it available to all descendant widgets in the tree.
4.  **Accessing State in UI (`home_screen.dart`):**
    *   **`Provider.of<PrayerTimesProvider>(context)`:** Used to get the current state values (e.g., `prayerProvider.isLoading`, `prayerProvider.prayerTimes`). The widget using this will rebuild whenever `notifyListeners()` is called.
    *   **`Consumer<PrayerTimesProvider>`:** An alternative widget that listens to the provider and provides the instance in its `builder` function. Useful for optimizing rebuilds to only specific parts of the widget tree (like the recent locations list).
    *   **`Provider.of<PrayerTimesProvider>(context, listen: false)`:** Used inside button callbacks (`onPressed`) or `initState` to call methods on the provider *without* causing the current widget to rebuild when the provider changes. Essential for triggering actions like fetching data or toggling settings.

---

## API Usage

*   **API Provider:** [Al Adhan API](https://aladhan.com/prayer-times-api)
*   **Endpoints Used:**
    *   `https://api.aladhan.com/v1/timings?latitude={lat}&longitude={lon}&method={m}&school={s}` (For GPS coordinates)
    *   `https://api.aladhan.com/v1/timingsByCity/:date?city={city}&country={country}&method={m}&school={s}` (For manual city input, where `:date` is `DD-MM-YYYY`)
*   **Key Parameters:** `latitude`, `longitude`, `city`, `country`, `method` (calculation method ID), `school` (Asr calculation - 0 for Standard, 1 for Hanafi), `date` (required in path for city lookups).
*   **Authentication:** Currently uses the free tier, no API key required. Note potential usage limits mentioned by the API provider.

---

## Setup & Running

1.  **Clone the Repository:**
    ```bash
    git clone <your-repository-url>
    cd salat_time
    ```
2.  **Ensure Flutter SDK:** Make sure you have the Flutter SDK installed and configured correctly. Verify with `flutter doctor`.
3.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Configure Permissions (Android):** Ensure these are declared in `android/app/src/main/AndroidManifest.xml`:
    ```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
    ```
    The app requests runtime notification permission. On Android 12+, enable "Exact alarms" for reliable background Adhan scheduling.
    *   **iOS:** Edit `ios/Runner/Info.plist` and add the following keys/strings inside the main `<dict>` tag:
        ```xml
        <key>NSLocationWhenInUseUsageDescription</key>
        <string>This app needs access to your location to calculate accurate prayer times for your current position.</string>
        <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
        <string>This app needs background location access for potential future features like notifications.</string>
        <key>NSLocationAlwaysUsageDescription</key>
        <string>This app needs background location access for potential future features like notifications.</string>
        ```
5.  **Connect Device/Emulator:** Connect a physical device (with USB Debugging enabled) or start an Android/iOS emulator/simulator.
6.  **Run the App:**
    ```bash
    flutter run
    ```

7.  **Adhan Audio Assets:** Declared in `pubspec.yaml` and bundled under:
        ```
        assets/audio/adhan/
            ├─ adhan_default.mp3
            ├─ adhan_makkah.mp3
            ├─ adhan_madinah_archive.mp3
            ├─ adhan_turkey.mp3
            └─ adhan_fajr_zahrani.mp3
        ```

---

## Configuration      

*   **Location Permissions:** As detailed in the Setup section, ensure the necessary permissions are added to the native configuration files (`AndroidManifest.xml` and `Info.plist`). The app will request these permissions at runtime when location is needed.
*   **Calculation Method:** Default is ISNA (2); configurable in Settings.
*   **Asr Juristic Method (School):** The default is hardcoded (currently Standard, ID=0). This could also be made configurable.

---

## Using the New Features

### Home Widget
* Shows next prayer and a live countdown.
* Updates every minute; tap any widget text to open the app.
* Menu → "Update Home Widget" to push an immediate refresh.

### Background Adhan & Notification
* The app schedules exact alarms for each prayer and plays Adhan even if the app is closed.
* When a prayer triggers, a high‑importance notification appears first, then Adhan starts; tap STOP to stop playback.

### Quick Test
* AppBar menu → "Test Adhan (1 min)"; press Home. After ~1 minute you should see a notification and hear the Adhan.
* Inline "Test" on each prayer row plays/stops a preview immediately while the app is open.

### Time Handling (UTC)
* All next‑prayer calculations and widget storage use UTC timestamps to avoid timezone/DST issues. Times are converted to local only for display.

## Troubleshooting

* Adhan only when app is open: Grant notification permission; on Android 12+ allow Exact alarms; disable battery optimization for the app; check media volume and DND.
* Widget stuck on Fajr: Wait up to a minute or use "Update Home Widget"; ensure location is set; UTC handling prevents DST/timezone drift.
* No notification sound: The app plays audio via `just_audio` and shows a notification without sound; use the STOP action to stop.
