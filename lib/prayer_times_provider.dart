import 'dart:async'; // Import async for Timer
import 'dart:convert'; // For jsonEncode/Decode
import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// --- Key names for SharedPreferences ---
const String _prefsKeyRecentLocations = 'recentLocations';
const String _prefsKeyIs24Hour = 'is24HourFormat';
const String _prefsKeyCalculationMethod = 'calculationMethod';
const String _prefsKeyLastSource = 'lastLocationSource'; // 'gps' or 'address'
const String _prefsKeyLastLat = 'lastLatitude';
const String _prefsKeyLastLon = 'lastLongitude';
const String _prefsKeyLastAddress = 'lastAddress'; // Storing the address string
const String _prefsKeyCachedTimes = 'cachedPrayerTimes';
const String _prefsKeyCachedHijri = 'cachedHijriDate';
const String _prefsKeyCachedGregorian = 'cachedGregorianDate';

// --- Calculation Methods Map ---
const Map<int, String> calculationMethods = {
  1: 'University of Islamic Sciences, Karachi',
  2: 'Islamic Society of North America (ISNA)',
  3: 'Muslim World League (MWL)',
  4: 'Umm al-Qura University, Makkah',
  5: 'Egyptian General Authority of Survey',
  7: 'Institute of Geophysics, University of Tehran',
  8: 'Gulf Region',
  9: 'Kuwait',
  10: 'Qatar',
  11: 'Majlis Ugama Islam Singapura, Singapore',
  12: 'Union Organization islamic de France',
  13: 'Diyanet İşleri Başkanlığı, Turkey',
  14: 'Spiritual Administration of Muslims of Russia',
  15: 'Moonsighting Committee Worldwide',
  16: 'Dubai (unofficial)',
  0: 'Shia Ithna-Ansari',
  99: 'Islamiska Förbundet (Custom 14.7/13.7)',
};
// --- Custom Angles ---
const double _customFajrAngle = 14.7;
const double _customIshaAngle = 13.7;

// --- Order of prayers for next prayer logic ---
const List<String> _prayerOrder = [
  // Order matters for finding the *next* prayer
  // API keys: Imsak, Fajr, Sunrise, Dhuhr, Asr, Sunset, Maghrib, Isha, Midnight
  // We'll use the ones typically displayed/relevant for highlighting
  'Imsak', 'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
];


class PrayerTimesProvider with ChangeNotifier {
  // --- State Variables ---
  Position? _currentPosition; // Current GPS position if fetched
  Map<String, dynamic>? _prayerTimes; // Current prayer times map (e.g., {'Fajr': '06:13', ...})
  Map<String, dynamic>? _hijriDateInfo; // Current Hijri date map from API
  Map<String, dynamic>? _gregorianDateInfo; // Current Gregorian date map from API
  String? _errorMessage; // Current error message, if any
  bool _isLoading = false; // Indicates if a fetch operation is in progress
  String? _currentAddress; // Optional display address (e.g., from reverse geocoding - not implemented)
  List<String> _recentLocations = []; // List of recent manual address searches
  bool _is24HourFormat = true; // User preference for time format
  int _calculationMethod = 3; // User preference for calculation method (Default MWL ID=3)

  // Last *successfully* used location info (loaded from/saved to prefs)
  String? _lastUsedLocationSource; // Last SUCCESSFUL source ('gps' or 'address')
  String? _lastUsedAddress;      // Last SUCCESSFUL address string used
  Position? _lastUsedPosition;     // Last SUCCESSFUL GPS position

  // State for Next Prayer logic
  String? _nextPrayerName; // Name of the upcoming prayer (e.g., 'Dhuhr')
  DateTime? _nextPrayerDateTime; // DateTime object for the upcoming prayer
  Timer? _nextPrayerTimer; // Timer to periodically check/update the next prayer

  // --- Getters ---
  Map<String, dynamic>? get prayerTimes => _prayerTimes;
  Map<String, dynamic>? get hijriDateInfo => _hijriDateInfo;
  Map<String, dynamic>? get gregorianDateInfo => _gregorianDateInfo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  List<String> get recentLocations => _recentLocations;
  bool get is24HourFormat => _is24HourFormat;
  int get calculationMethod => _calculationMethod;
  Map<int, String> get availableCalculationMethods => calculationMethods; // Expose the map for dropdown
  // Getters for displaying the location associated with the *currently loaded* times
  String? get lastUsedLocationSource => _lastUsedLocationSource;
  String? get lastUsedAddressForDisplay => _lastUsedAddress;
  Position? get lastUsedPositionForDisplay => _lastUsedPosition;
  // Getters for next prayer info for the UI
  String? get nextPrayerName => _nextPrayerName;
  DateTime? get nextPrayerDateTime => _nextPrayerDateTime; // UI could use this for countdown

  // --- Initialization ---
  PrayerTimesProvider() {
    _loadPreferencesAndCachedData(); // Load saved state when the provider is created
  }

  // --- Cleanup ---
  @override
  void dispose() {
    _nextPrayerTimer?.cancel(); // Important: Cancel timer to prevent memory leaks
    super.dispose();
  }

  // --- Loading Logic ---
  Future<void> _loadPreferencesAndCachedData() async {
    print("Loading preferences and cached data...");
    _isLoading = true;
    // Don't notify yet, let the finally block do it once after loading attempt
    // notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load user preferences
      _recentLocations = prefs.getStringList(_prefsKeyRecentLocations) ?? [];
      _is24HourFormat = prefs.getBool(_prefsKeyIs24Hour) ?? true; // Default to true if not found
      _calculationMethod = prefs.getInt(_prefsKeyCalculationMethod) ?? 3; // Default MWL
      // Validate loaded method ID against our known methods
      if (!calculationMethods.containsKey(_calculationMethod)) {
        print("Warning: Loaded invalid calculation method ID ($_calculationMethod), resetting to default (3).");
        _calculationMethod = 3;
      }

      // Load info about the last *successful* fetch
      _lastUsedLocationSource = prefs.getString(_prefsKeyLastSource);
      double? lastLat = prefs.getDouble(_prefsKeyLastLat);
      double? lastLon = prefs.getDouble(_prefsKeyLastLon);
      _lastUsedAddress = prefs.getString(_prefsKeyLastAddress);

      // Reconstruct Position object if lat/lon were saved
      if (lastLat != null && lastLon != null) {
        _lastUsedPosition = Position(longitude: lastLon, latitude: lastLat, timestamp: DateTime.now(), accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);
      } else {
        _lastUsedPosition = null;
      }

      // Load the actual cached prayer time and date data (as JSON strings)
      String? cachedTimesJson = prefs.getString(_prefsKeyCachedTimes);
      String? cachedHijriJson = prefs.getString(_prefsKeyCachedHijri);
      String? cachedGregorianJson = prefs.getString(_prefsKeyCachedGregorian);

      // Attempt to decode JSON and populate state variables
      Map<String, dynamic>? loadedTimes;
      Map<String, dynamic>? loadedHijri;
      Map<String, dynamic>? loadedGregorian;

      if (cachedTimesJson != null) {
        try { loadedTimes = jsonDecode(cachedTimesJson); } catch (e) { print("Error decoding cached prayer times JSON: $e"); }
      }
      if (cachedHijriJson != null) {
        try { loadedHijri = jsonDecode(cachedHijriJson); } catch (e) { print("Error decoding cached Hijri date JSON: $e"); }
      }
      if (cachedGregorianJson != null) {
        try { loadedGregorian = jsonDecode(cachedGregorianJson); } catch (e) { print("Error decoding cached Gregorian date JSON: $e"); }
      }

      // Assign to state *only if* all essential parts were successfully decoded
      if (loadedTimes != null && loadedHijri != null && loadedGregorian != null) {
        _prayerTimes = loadedTimes;
        _hijriDateInfo = loadedHijri;
        _gregorianDateInfo = loadedGregorian;
        print("Successfully loaded cached data for source: $_lastUsedLocationSource");
        // Determine the current position display based on the source of the cached data
        if (_lastUsedLocationSource == 'gps') {
          _currentPosition = _lastUsedPosition; // Show the coords used for this cache
        } else {
          _currentPosition = null; // Don't show coords if cache is from address search
        }
        // Calculate the next prayer based on the loaded times
        _calculateAndSetNextPrayer();
      } else {
        print("Cached data was incomplete, missing, or corrupted. Will require fresh fetch.");
        // Ensure state is clear if loading failed
        _prayerTimes = null;
        _hijriDateInfo = null;
        _gregorianDateInfo = null;
        // Optionally clear last used info if cache is invalid? Or keep it for refetch? Keep for refetch.
      }

    } catch (e) {
      print("Error loading preferences/cache: $e");
      _errorMessage = "Failed to load saved data.";
      // Clear all related state on critical error
      _prayerTimes = null; _hijriDateInfo = null; _gregorianDateInfo = null;
      _lastUsedAddress = null; _lastUsedPosition = null; _lastUsedLocationSource = null;
      _recentLocations = []; _calculationMethod = 3;
    } finally {
      _isLoading = false; // Loading process finished
      notifyListeners(); // Update UI with loaded data, lack thereof, or error state
    }
  }

  // --- Save Successful Fetch Data ---
  Future<void> _saveSuccessfulFetch({
    required String source,          // 'gps' or 'address'
    Position? position,              // The position used (if source is 'gps')
    String? address,                 // The address string used (if source is 'address')
    required Map<String, dynamic> times, // The fetched prayer times
    required Map<String, dynamic> hijri, // The fetched Hijri date info
    required Map<String, dynamic> gregorian // The fetched Gregorian date info
  }) async {
    print("Saving successful fetch data. Source: $source");
    try {
      final prefs = await SharedPreferences.getInstance();

      // --- Persist Preferences Used for This Fetch ---
      await prefs.setInt(_prefsKeyCalculationMethod, _calculationMethod);

      // --- Persist Location Info for This Fetch ---
      await prefs.setString(_prefsKeyLastSource, source);
      if (source == 'gps' && position != null) {
        await prefs.setDouble(_prefsKeyLastLat, position.latitude);
        await prefs.setDouble(_prefsKeyLastLon, position.longitude);
        await prefs.remove(_prefsKeyLastAddress); // Clear stale address key
      } else if (source == 'address' && address != null) {
        await prefs.setString(_prefsKeyLastAddress, address); // Save the address string
        await prefs.remove(_prefsKeyLastLat); // Clear stale GPS keys
        await prefs.remove(_prefsKeyLastLon);
      }

      // --- Persist Fetched Data (Cache) ---
      await prefs.setString(_prefsKeyCachedTimes, jsonEncode(times));
      await prefs.setString(_prefsKeyCachedHijri, jsonEncode(hijri));
      await prefs.setString(_prefsKeyCachedGregorian, jsonEncode(gregorian));

      print("Successfully saved fetch data to SharedPreferences.");

    } catch (e) {
      print("Error saving fetch data to SharedPreferences: $e");
      // Optionally notify user of saving error? Generally fail silently.
    }
  }

  // --- Persistence Methods (User Actions) ---
  Future<void> _saveRecentLocation(String location) async {
    // Manages the list of recent *manual search strings*
    final trimmedLocation = location.trim();
    if (trimmedLocation.isEmpty) return;
    // Remove if already exists to move it to the top
    _recentLocations.remove(trimmedLocation);
    _recentLocations.insert(0, trimmedLocation);
    // Limit to 3 recent items
    if (_recentLocations.length > 3) {
      _recentLocations = _recentLocations.sublist(0, 3);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKeyRecentLocations, _recentLocations);
      notifyListeners(); // Update UI showing recent locations
    } catch (e) {
      print("Error saving recent location list: $e");
    }
  }

  Future<void> toggleTimeFormat() async {
    _is24HourFormat = !_is24HourFormat;
    notifyListeners(); // Update UI immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyIs24Hour, _is24HourFormat);
    } catch (e) {
      print("Error saving time format preference: $e");
    }
  }

  Future<void> setCalculationMethod(int methodId) async {
    // Updates the selected method in state and saves preference
    if (calculationMethods.containsKey(methodId)) {
      if (_calculationMethod != methodId) { // Only update if different
        _calculationMethod = methodId;
        notifyListeners(); // Update dropdown UI immediately
        try {
          final prefs = await SharedPreferences.getInstance();
          // Save immediately so it persists even if user doesn't refetch
          await prefs.setInt(_prefsKeyCalculationMethod, _calculationMethod);
          print("Calculation method set and saved: $methodId - ${calculationMethods[methodId]}");
        } catch (e) {
          print("Error saving calculation method preference: $e");
        }
      }
    } else {
      print("Error: Attempted to set invalid calculation method ID: $methodId");
    }
  }

  // --- Refetch Logic ---
  Future<void> refetchLastUsedLocation() async {
    // Uses the state loaded from prefs (_lastUsed...) to trigger a fresh API call
    print("Attempting to refetch last used location. Source: $_lastUsedLocationSource");

    // Get the necessary details from the *current* state (which reflects the last saved state)
    final source = _lastUsedLocationSource;
    final position = _lastUsedPosition; // Not directly used, fetchTimesByGps gets new coords
    final address = _lastUsedAddress;

    // Clear current display data and next prayer info before refetching
    await _clearStateBeforeFetch();

    if (source == 'gps') {
      // Re-trigger the full GPS flow. It will get fresh coordinates.
      await fetchTimesByGps();
    } else if (source == 'address' && address != null) {
      // Use the stored address string to refetch
      await fetchTimesByAddress(address);
    } else {
      print("No valid last used location found in state to refetch.");
      _errorMessage = "No previous location available to refresh.";
      // Ensure loading is stopped if we can't refetch
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Core Logic Methods ---
  Future<void> _clearStateBeforeFetch() async {
    // Clears data that needs refreshing, keeps user prefs and last used info
    _isLoading = true;
    _errorMessage = null;
    _prayerTimes = null;
    _hijriDateInfo = null;
    _gregorianDateInfo = null;
    _currentPosition = null; // Clear current GPS display before attempting fetch
    // Clear next prayer info as well
    _nextPrayerName = null;
    _nextPrayerDateTime = null;
    _nextPrayerTimer?.cancel(); // Cancel any active timer
    notifyListeners(); // Show loading state, clear old data from UI
  }

  Future<void> fetchTimesByGps() async {
    await _clearStateBeforeFetch();
    Position? fetchedPosition; // Variable to hold the position obtained in *this* fetch
    try {
      // --- Permission & Service Check ---
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are denied.');
        }
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
      // --- Get Location ---
      print("Getting current GPS position...");
      fetchedPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium // Medium accuracy is usually sufficient and faster
      );
      print("Got position: ${fetchedPosition.latitude}, ${fetchedPosition.longitude}");
      _currentPosition = fetchedPosition; // Update UI to show position quickly
      notifyListeners();

      // --- Fetch Times using the obtained coordinates ---
      await _fetchPrayerTimes(
        latitude: fetchedPosition.latitude,
        longitude: fetchedPosition.longitude,
        address: null, // Explicitly null for GPS call
      );

      // --- Process Success (if fetch succeeded and populated data) ---
      if (_prayerTimes != null && _hijriDateInfo != null && _gregorianDateInfo != null) {
        // Update last used state in memory
        _lastUsedLocationSource = 'gps';
        _lastUsedPosition = fetchedPosition; // Store the *successfully used* position
        _lastUsedAddress = null; // Clear address state
        // Persist this successful state
        await _saveSuccessfulFetch(
            source: 'gps',
            position: fetchedPosition,
            address: null,
            times: _prayerTimes!,
            hijri: _hijriDateInfo!,
            gregorian: _gregorianDateInfo!
        );
        // Calculate the next prayer based on the newly fetched times
        _calculateAndSetNextPrayer();
      } else {
        // If _fetchPrayerTimes didn't throw but data is still null, something's wrong
        if(_errorMessage == null) _errorMessage = "API call succeeded but prayer data was incomplete.";
        // Let finally block handle notifyListeners
      }

    } catch (e) {
      print("Error in fetchTimesByGps: $e");
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false; // Ensure loading state is turned off
      notifyListeners(); // Update UI with results, error, or cleared loading state
    }
  }

  Future<void> fetchTimesByAddress(String address) async {
    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) {
      _errorMessage = "Please enter a location or address.";
      notifyListeners();
      return; // Don't proceed if input is empty
    }
    await _clearStateBeforeFetch();
    _currentPosition = null; // Ensure GPS position is not displayed

    try {
      // --- Fetch Times using the provided address ---
      await _fetchPrayerTimes(
          latitude: null, longitude: null, // Explicitly null for address call
          address: trimmedAddress);

      // --- Process Success ---
      if (_prayerTimes != null && _hijriDateInfo != null && _gregorianDateInfo != null) {
        // Update last used state in memory
        _lastUsedLocationSource = 'address';
        _lastUsedAddress = trimmedAddress;    // Store the successfully used address
        _lastUsedPosition = null;         // Clear position state
        // Persist successful state
        await _saveRecentLocation(trimmedAddress); // Also save to recent list
        await _saveSuccessfulFetch(
            source: 'address',
            position: null,
            address: trimmedAddress,
            times: _prayerTimes!,
            hijri: _hijriDateInfo!,
            gregorian: _gregorianDateInfo!
        );
        // Calculate next prayer based on newly fetched times
        _calculateAndSetNextPrayer();
      } else {
        if(_errorMessage == null) _errorMessage = "API call succeeded but prayer data was incomplete.";
        // Let finally block handle notifyListeners
      }

    } catch (e) {
      print("Error in fetchTimesByAddress: $e");
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false; // Ensure loading state is turned off
      notifyListeners(); // Update UI with results, error, or cleared loading state
    }
  }

  // --- API Call Helper ---
  Future<void> _fetchPrayerTimes(
      {double? latitude, double? longitude, String? address}) async {
    Uri url;
    Map<String, String> queryParams = { 'school': '0' }; // Base parameter (Asr calculation method)
    // --- Add Method/Angle Parameters ---
    if (_calculationMethod == 99) { // Handle Custom Method
      queryParams['method'] = '99';
      queryParams['fajrAngle'] = _customFajrAngle.toString();
      queryParams['ishaAngle'] = _customIshaAngle.toString();
      print("API Call using Custom Method 99 (Angles: Fajr=${queryParams['fajrAngle']}, Isha=${queryParams['ishaAngle']})");
    } else { // Handle Standard Method
      queryParams['method'] = _calculationMethod.toString();
      print("API Call using Standard Method ID: ${queryParams['method']}");
    }

    // --- Determine Endpoint and Location Parameters ---
    String path;
    if (latitude != null && longitude != null) { // GPS Call uses /timings/:timestamp
      queryParams['latitude'] = latitude.toString();
      queryParams['longitude'] = longitude.toString();
      String timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      path = '/v1/timings/$timestamp';
      print("API Target: Coordinates ($latitude, $longitude)");
    } else if (address != null && address.isNotEmpty) { // Address Call uses /timingsByAddress/:date
      queryParams['address'] = address;
      DateTime now = DateTime.now();
      String formattedDate = DateFormat('dd-MM-yyyy').format(now);
      path = '/v1/timingsByAddress/$formattedDate';
      print("API Target: Address ('$address')");
    } else {
      // This should not happen if called from fetchTimesByGps or fetchTimesByAddress correctly
      throw Exception("Internal Error: Insufficient location information provided to _fetchPrayerTimes.");
    }
    // Construct the final URL
    url = Uri.https('api.aladhan.com', path, queryParams);
    print("Fetching from URL: $url");

    // --- Execute API Call and Handle Response ---
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15)); // Add timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // **Crucial Check**: Ensure API call was successful AND data is present
        if (data['code'] == 200
            && data['data']?['timings'] != null
            && data['data']?['date']?['hijri'] != null
            && data['data']?['date']?['gregorian'] != null
        ) {
          // Update provider state with FRESH data from API
          // Assign directly to state variables
          _prayerTimes = Map<String, String>.from(data['data']['timings']); // Ensure correct type
          _hijriDateInfo = data['data']['date']['hijri'];
          _gregorianDateInfo = data['data']['date']['gregorian'];
          _errorMessage = null; // Clear previous errors on success
          print("API Fetch successful.");
        } else {
          // Handle cases where API returns 200 but data is invalid/missing or status code within JSON is not 200
          String apiStatus = data['status'] ?? 'API Error (Unknown Status)';
          if (data['code'] != 200) apiStatus = "API returned code ${data['code']}: $apiStatus";
          if (data['data']?['timings'] == null) apiStatus += " (Missing timings data)";
          if (data['data']?['date']?['hijri'] == null) apiStatus += " (Missing Hijri date data)";
          if (data['data']?['date']?['gregorian'] == null) apiStatus += " (Missing Gregorian date data)";
          // Check specific error messages from API response data field
          if (data['data'] is String && data['data'].contains("Invalid address specified")) {
            apiStatus = "Address '$address' not found or invalid. Please be more specific.";
          } else if (apiStatus.contains("Cannot find the specified city")) { // Keep city check just in case
            apiStatus = "City could not be resolved from address '$address'.";
          }
          throw Exception(apiStatus); // Throw combined status/error message
        }
      } else {
        // Handle non-200 HTTP status codes
        print("API Error: Status Code ${response.statusCode}, Body: ${response.body}");
        String errorMsg = 'Network Error (Status: ${response.statusCode})'; // Default network error
        try {
          // Try to parse a more specific error message from the API response body
          final errorData = jsonDecode(response.body);
          // API often puts error detail in 'data' field for non-200 responses
          if(errorData['data'] is String) {
            errorMsg = errorData['data']; // Use specific API error message
            // Refine common errors
            if (errorMsg.contains("Invalid address specified") || errorMsg.contains("Please specify an address")) {
              errorMsg = "Address '$address' not found or invalid. Please be more specific. (Code: ${response.statusCode})";
            } else if (errorMsg.contains("Invalid date") || errorMsg.contains("Date must be")){
              errorMsg = "Invalid date format sent to API. (Code: ${response.statusCode})"; // Should not happen with current code
            } else {
              errorMsg = "API Error: $errorMsg (Code: ${response.statusCode})"; // Prepend generic API Error
            }
          } else if (errorData['status'] is String){
            errorMsg = "API Error: ${errorData['status']} (Code: ${response.statusCode})";
          }
        } catch (e) {
          // Ignore JSON parsing errors if response body is not valid JSON
          print("Could not parse error response body as JSON.");
        }
        throw Exception(errorMsg); // Throw the determined error message
      }
    } on TimeoutException catch (_) {
      print("API call timed out.");
      throw Exception('Failed to fetch times: The request timed out.');
    } on http.ClientException catch (e) {
      print("Network error during API call: $e");
      throw Exception('Failed to fetch times: Network error.');
    } catch (e) {
      // Catch all other errors (parsing, exceptions thrown above)
      print("Caught error during API fetch processing: $e");
      // Rethrow simplified message for UI display
      throw Exception('Failed to fetch times: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // --- Next Prayer Calculation Logic ---
  void _calculateAndSetNextPrayer() {
    _nextPrayerTimer?.cancel(); // Cancel previous timer before starting calculation
    if (_prayerTimes == null) {
      print("Cannot calculate next prayer: Prayer times data is null.");
      // Ensure state is cleared if times become null
      bool changed = _nextPrayerName != null || _nextPrayerDateTime != null;
      _nextPrayerName = null;
      _nextPrayerDateTime = null;
      if (changed) notifyListeners();
      return;
    }

    DateTime now = DateTime.now();
    DateTime? nextPrayerTimeFound;
    String? nextPrayerNameFound;

    // Use today's date for parsing times relative to the current day
    DateTime today = DateTime(now.year, now.month, now.day);

    print("Calculating next prayer relative to: $now");

    // Iterate through the defined prayer order
    for (String prayerName in _prayerOrder) {
      String? timeString = _prayerTimes![prayerName];
      if (timeString == null) {
        print("Skipping $prayerName: Time data missing.");
        continue; // Skip if time is missing in the API response for this prayer
      }

      try {
        // Parse time string (expecting HH:mm)
        List<String> parts = timeString.split(':');
        if (parts.length != 2) {
          print("Skipping $prayerName: Invalid time format '$timeString'.");
          continue; // Invalid format
        }
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        // Create DateTime object for today's prayer time
        DateTime prayerDt = today.add(Duration(hours: hour, minutes: minute));

        // Check if this prayer time is after the current time
        if (prayerDt.isAfter(now)) {
          nextPrayerTimeFound = prayerDt;
          nextPrayerNameFound = prayerName;
          print("Found next prayer for today: $nextPrayerNameFound at $nextPrayerTimeFound");
          break; // Found the first upcoming prayer for today, stop searching
        }
      } catch (e) {
        // Catch parsing errors (e.g., non-integer parts)
        print("Error parsing time for $prayerName ('$timeString'): $e");
        continue; // Skip this prayer if parsing fails
      }
    }

    // If no upcoming prayer found for today (i.e., current time is after Isha)
    if (nextPrayerNameFound == null) {
      print("Current time is after Isha, checking tomorrow's Fajr.");
      String? fajrTimeString = _prayerTimes!['Fajr']; // Get Fajr time string again
      if (fajrTimeString != null) {
        try {
          List<String> parts = fajrTimeString.split(':');
          if (parts.length == 2) {
            int hour = int.parse(parts[0]);
            int minute = int.parse(parts[1]);
            // Create DateTime object for *tomorrow's* Fajr
            DateTime tomorrow = today.add(const Duration(days: 1));
            nextPrayerTimeFound = tomorrow.add(Duration(hours: hour, minutes: minute));
            nextPrayerNameFound = 'Fajr'; // Next prayer is Fajr
            print("Next prayer is tomorrow's Fajr at $nextPrayerTimeFound");
          } else {
            print("Invalid time format for tomorrow's Fajr: '$fajrTimeString'.");
            nextPrayerTimeFound = null; nextPrayerNameFound = null; // Clear if parsing fails
          }
        } catch (e) {
          print("Error parsing tomorrow's Fajr time ('$fajrTimeString'): $e");
          // Clear if parsing fails
          nextPrayerTimeFound = null;
          nextPrayerNameFound = null;
        }
      } else {
        print("Could not find Fajr time to calculate tomorrow's next prayer.");
        // Clear if Fajr time is missing
        nextPrayerTimeFound = null;
        nextPrayerNameFound = null;
      }
    }

    // --- Update State and Start Timer ---
    // Check if the calculated next prayer is different from the current state
    bool hasChanged = _nextPrayerName != nextPrayerNameFound || _nextPrayerDateTime != nextPrayerTimeFound;

    _nextPrayerName = nextPrayerNameFound;
    _nextPrayerDateTime = nextPrayerTimeFound;

    if (hasChanged) {
      print("Next prayer state updated. Notifying listeners.");
      notifyListeners(); // Notify UI about the change in next prayer
    }

    // If we successfully found the next prayer time, set a timer to recalculate later
    if (_nextPrayerDateTime != null) {
      // Calculate duration until the next prayer time passes (add a small buffer)
      Duration timeUntilRecalculate = _nextPrayerDateTime!.difference(now) + const Duration(seconds: 10); // Recalc 10s after prayer time passes
      // Ensure duration is not negative if calculation happens slightly after the time
      if (timeUntilRecalculate.isNegative) {
        timeUntilRecalculate = const Duration(seconds: 30); // Recalculate soon if already past
      }

      print("Scheduling timer to recalculate next prayer in $timeUntilRecalculate");
      _nextPrayerTimer = Timer(timeUntilRecalculate, () {
        print("Timer fired: Recalculating next prayer.");
        _calculateAndSetNextPrayer(); // Call this function again after the time passes
      });
    } else {
      print("Could not determine next prayer. No timer scheduled.");
    }
  }

  // --- Formatting Helpers ---
  String formatTime(String time24) {
    // Formats HH:mm string to user preference (12h/24h)
    try {
      final time = DateFormat('HH:mm', 'en_US').parse(time24); // Specify locale for parsing robustness
      final format = _is24HourFormat ? DateFormat('HH:mm', 'en_US') : DateFormat('h:mm a', 'en_US'); // Locale for AM/PM
      return format.format(time);
    } catch (e) {
      print("Error formatting time '$time24': $e");
      return time24; // Return original string if parsing fails
    }
  }

  String formatHijriDate(Map<String, dynamic>? hijriData) {
    // Formats Hijri date map from API into readable string
    if (hijriData == null) return '';
    try {
      String day = hijriData['day'] ?? '';
      String month = hijriData['month']?['en'] ?? ''; // Use English month name
      String year = hijriData['year'] ?? '';
      String designation = hijriData['designation']?['abbreviated'] ?? 'AH'; // e.g., AH
      if (day.isNotEmpty && month.isNotEmpty && year.isNotEmpty) {
        return "$day $month $year $designation"; // e.g., "2 Ramadan 1445 AH"
      } else {
        return 'Hijri date unavailable';
      }
    } catch (e) {
      print("Error formatting Hijri date: $e");
      return 'Error'; // Return simple error string
    }
  }

  String formatGregorianDate(Map<String, dynamic>? gregorianData) {
    // Formats Gregorian date map from API into readable string
    if (gregorianData == null) return '';
    try {
      String day = gregorianData['day'] ?? '';
      String month = gregorianData['month']?['en'] ?? ''; // Use English month name
      String year = gregorianData['year'] ?? '';
      String weekday = gregorianData['weekday']?['en'] ?? ''; // Use English weekday

      if (day.isNotEmpty && month.isNotEmpty && year.isNotEmpty && weekday.isNotEmpty) {
        return "$weekday, $day $month $year"; // e.g., "Friday, 12 April 2024"
      } else {
        return 'Date unavailable';
      }
    } catch(e) {
      print("Error formatting Gregorian date: $e");
      return 'Error'; // Return simple error string
    }
  }

} // End of PrayerTimesProvider clas