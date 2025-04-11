# Salat Time - Prayer Times Flutter App

A simple yet functional Flutter application designed to provide Muslims with accurate daily prayer (Salat) times based on their location. The app can fetch times using the device's GPS or by manually entering a city name.

**(Optional: Add Screenshots Here)**
<!-- ![Screenshot 1](link/to/screenshot1.png) -->
<!-- ![Screenshot 2](link/to/screenshot2.png) -->

---

## Features

*   **Splash Screen:** Simple introductory screen displaying the app name on launch.
*   **Automatic Location Detection:** Uses the device's GPS to fetch precise prayer times for the current location (`geolocator` package).
*   **Manual Location Input:** Allows users to enter a city name (optionally with country) to fetch prayer times.
*   **Recent Locations:** Stores and displays the last 3 manually searched locations for quick access (`shared_preferences`).
*   **Daily Prayer Times Display:** Shows the calculated times for Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha.
*   **Time Formatting Toggle:** Users can switch between 12-hour (AM/PM) and 24-hour time formats. Preference is saved (`shared_preferences`, `intl`).
*   **API Integration:** Fetches prayer times from the reliable [Al Adhan API](https://aladhan.com/prayer-times-api).
*   **State Management:** Uses the `provider` package for managing application state effectively.
*   **Basic Error Handling:** Displays informative messages for issues like missing permissions, disabled location services, network errors, or invalid city names.

## Future Enhancements (Potential Ideas)

*   Qibla Direction Compass
*   Prayer Time Notifications / Adhan Alerts
*   Hijri Calendar Display
*   Monthly Prayer Times View
*   Settings Screen (Calculation Method, Asr Juristic Method, Time Adjustments, Madhab)
*   Improved UI/UX Themes (Light/Dark Mode)
*   Offline Caching of Prayer Times
*   Widget Support

---

## Technology Stack & Key Dependencies

*   **Framework:** Flutter (`sdk: flutter`)
*   **Language:** Dart
*   **State Management:** [`provider`](https://pub.dev/packages/provider) - For managing and listening to application state changes.
*   **Location:** [`geolocator`](https://pub.dev/packages/geolocator) - For accessing device GPS and handling location permissions.
*   **Networking:** [`http`](https://pub.dev/packages/http) - For making HTTP requests to the Al Adhan API.
*   **Persistence:** [`shared_preferences`](https://pub.dev/packages/shared_preferences) - For storing user preferences (time format) and recent locations locally.
*   **Date/Time Formatting:** [`intl`](https://pub.dev/packages/intl) - For formatting dates (for API requests) and times (for display).
*   **Icons:** [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) (Default Flutter dependency)

---

## Project Structure

The project follows a standard Flutter structure:
salat_time/
├── android/ # Android platform-specific files
├── ios/ # iOS platform-specific files
├── lib/ # Main Dart code for the application
│ ├── main.dart # App entry point, MaterialApp setup, Provider setup
│ ├── splash_screen.dart # Implements the splash screen UI and navigation logic
│ ├── home_screen.dart # Implements the main UI (input, recents, times display)
│ └── prayer_times_provider.dart # State management, business logic, API calls
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
4.  **Configure Permissions:**
    *   **Android:** Edit `android/app/src/main/AndroidManifest.xml` and ensure the following permissions are present inside the `<manifest>` tag:
        ```xml
        <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
        <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
        <!-- Internet permission is usually implicit but good to have -->
        <uses-permission android:name="android.permission.INTERNET"/>
        ```
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

---

## Configuration

*   **Location Permissions:** As detailed in the Setup section, ensure the necessary permissions are added to the native configuration files (`AndroidManifest.xml` and `Info.plist`). The app will request these permissions at runtime when location is needed.
*   **Calculation Method:** The default calculation method is hardcoded (currently ISNA, ID=2) in `prayer_times_provider.dart`. This could be made configurable via a settings screen in the future.
*   **Asr Juristic Method (School):** The default is hardcoded (currently Standard, ID=0). This could also be made configurable.

---

## License

[Specify License Here - e.g., MIT, Apache 2.0, etc.]