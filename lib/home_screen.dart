import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'prayer_times_provider.dart'; // Ensure this path is correct
import 'package:flutter/services.dart'; // Needed for FontFeature

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controller for the manual location text field
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Provider's constructor now handles initial loading
  }

  @override
  void dispose() {
    _locationController.dispose(); // Clean up the controller
    super.dispose();
  }

  // Function to trigger manual search using address
  void _searchManualLocation() {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    final String address = _locationController.text.trim();

    if (address.isNotEmpty) {
      FocusScope.of(context).unfocus(); // Hide keyboard
      provider.fetchTimesByAddress(address); // Call the correct method
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a location or address."),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating, // Optional: make snackbar float
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get non-listening provider instance once for actions like button presses
    final prayerProviderInstance = Provider.of<PrayerTimesProvider>(context, listen: false);

    return Scaffold(
      // --- AppBar with Gradient and Actions ---
      appBar: AppBar(
        title: const Text('Salat Time', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 2, // Subtle shadow below AppBar
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal[700]!, Colors.green[800]!], // Adjusted gradient colors
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // Make icons white
        actionsIconTheme: const IconThemeData(color: Colors.white), // Make action icons white
        actions: [
          // --- Placeholder Action Buttons (Example) ---
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Calendar View (Future)',
            onPressed: () { /* TODO: Implement Calendar View */ },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share (Future)',
            onPressed: () { /* TODO: Implement Sharing */ },
          ),

          // --- Time Format Toggle (Uses Selector for performance) ---
          Selector<PrayerTimesProvider, bool>(
            selector: (_, provider) => provider.is24HourFormat,
            builder: (context, is24Hour, _) => IconButton(
              icon: Icon(is24Hour ? Icons.access_time : Icons.access_time_filled),
              tooltip: is24Hour ? 'Switch to 12-Hour Format' : 'Switch to 24-Hour Format',
              onPressed: () {
                prayerProviderInstance.toggleTimeFormat(); // Use non-listening instance
              },
            ),
          ),

          // --- GPS Refresh Button (Uses Selector for performance) ---
          Selector<PrayerTimesProvider, bool>(
            selector: (_, provider) => provider.isLoading, // Rebuilds only when isLoading changes
            builder: (context, isLoading, _) => IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'Get Times for Current Location',
              onPressed: isLoading ? null : () { // Disable if loading
                prayerProviderInstance.fetchTimesByGps(); // Use non-listening instance
              },
            ),
          ),
        ],
      ),
      // --- Main Body Content ---
      body: Container(
        color: Colors.grey[100], // Light background for the body content area
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Top Info Section (Location, Method - uses Consumer) ---
            _buildTopInfoSection(),

            // --- Date Display (Gregorian & Hijri - uses Consumer) ---
            _buildDateDisplay(),

            // --- Prayer Times List Area (uses Consumer) ---
            Expanded(
              // Consumer needed here to rebuild the list/state display on various changes
              child: Consumer<PrayerTimesProvider>(
                  builder: (context, provider, child) {
                    // Pass the provider instance to the helper method
                    return _buildPrayerTimesDisplay(provider);
                  }
              ),
            ),

            // --- Bottom Section (Manual Input, Recents, Dropdown - moved here) ---
            _buildBottomInputSection(), // This section contains the calls that caused the errors

          ],
        ),
      ),
    );
  }

  // --- Helper Widget Sections ---

  // Builds the top section showing current location and calculation method
  Widget _buildTopInfoSection() {
    // Use Consumer to react to location/method changes
    return Consumer<PrayerTimesProvider>(
        builder: (context, provider, child) {
          String locationDisplay = "Set Location Below"; // Default prompt
          final lastSource = provider.lastUsedLocationSource;
          final lastPos = provider.lastUsedPositionForDisplay;
          final lastAddr = provider.lastUsedAddressForDisplay;
          final calcMethodName = provider.availableCalculationMethods[provider.calculationMethod] ?? "Unknown Method";

          // Determine location string based on last successful fetch source
          if(lastSource == 'gps' && lastPos != null) {
            locationDisplay = 'Current Location (GPS)'; // Simplified GPS display
          } else if (lastSource == 'address' && lastAddr != null){
            locationDisplay = lastAddr; // Show the full address string used
          } else if (provider.isLoading && provider.prayerTimes == null) {
            locationDisplay = "Loading Location..."; // Show loading if relevant
          }

          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                  color: Colors.white, // White background for this section
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationDisplay,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Method: $calcMethodName",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
          );
        }
    );
  }

  // Builds the date display section (Gregorian and Hijri)
  Widget _buildDateDisplay() {
    // Uses Consumer to rebuild when date info changes
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        String formattedGregorian = provider.formatGregorianDate(provider.gregorianDateInfo);
        String formattedHijri = provider.formatHijriDate(provider.hijriDateInfo);

        // Hide if initial loading, or error, or no dates available at all
        if (provider.isLoading && provider.prayerTimes == null ||
            provider.errorMessage != null ||
            (formattedGregorian.isEmpty || formattedGregorian.contains('unavailable') || formattedGregorian == 'Error') &&
                (formattedHijri.isEmpty || formattedHijri.contains('unavailable') || formattedHijri == 'Error') ) {
          // Return a fixed height placeholder to prevent layout jumps during load
          return const SizedBox(height: 50); // Adjust height as needed
        }
        // Show placeholder if times exist but dates don't (unlikely but possible)
        if (provider.prayerTimes != null && (formattedGregorian.isEmpty || formattedGregorian.contains('unavailable') || formattedGregorian == 'Error') && (formattedHijri.isEmpty || formattedHijri.contains('unavailable') || formattedHijri == 'Error')) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 15.0), // Consistent padding
            alignment: Alignment.center,
            child: Text("Date Information Unavailable", style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          );
        }

        // Display available dates, centered
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 15.0),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!))
          ),
          child: Column(
            children: [
              if (formattedGregorian.isNotEmpty && !formattedGregorian.contains('unavailable') && formattedGregorian != 'Error')
                Text(
                  formattedGregorian, // e.g., "Friday, 12 April 2024"
                  textAlign: TextAlign.center,
                  style: TextStyle( fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800] ),
                ),
              if (formattedHijri.isNotEmpty && !formattedHijri.contains('unavailable') && formattedHijri != 'Error')
                Padding(
                  padding: const EdgeInsets.only(top: 4.0), // Space between dates
                  child: Text(
                    formattedHijri, // e.g., "2 Ramadan 1445 AH"
                    textAlign: TextAlign.center,
                    style: TextStyle( fontSize: 15, color: Colors.teal[800] ), // Keep Hijri distinct
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Builds the main section displaying loading indicator, error, or prayer times list
  Widget _buildPrayerTimesDisplay(PrayerTimesProvider provider) {
    // Loading state: Show indicator only during initial load when no times are cached
    if (provider.isLoading && provider.prayerTimes == null && provider.errorMessage == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      ));
    }
    // Error state: Show error message and retry button
    else if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // More padding for error
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 50),
              const SizedBox(height: 15),
              Text(
                // Display the error message from the provider
                'Error: ${provider.errorMessage}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 16),
              ),
              const SizedBox(height: 25),
              // Retry button
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Last'),
                onPressed: provider.isLoading ? null : () { // Disable if trying again
                  Provider.of<PrayerTimesProvider>(context, listen: false)
                      .refetchLastUsedLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600], // Use red for error retry?
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Initial prompt state: No times loaded, not loading, no error
    else if (provider.prayerTimes == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 60, color: Colors.grey[400]), // Changed icon
              const SizedBox(height: 20),
              Text(
                'Prayer times will appear here.\nUse GPS 📍 or search below 👇', // Updated prompt
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, color: Colors.grey[700], height: 1.4), // Increased line height
              ),
            ],
          ),
        ),
      );
    }
    // Success state: Display the list of prayer times
    else {
      final times = provider.prayerTimes!;
      final nextPrayer = provider.nextPrayerName; // Get name of next prayer from provider

      // Define the order to display prayers including Imsak and Sunrise
      const displayOrder = ['Imsak', 'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

      return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
          itemCount: displayOrder.length,
          itemBuilder: (context, index) {
            final prayerName = displayOrder[index];
            final prayerTime = times[prayerName]; // Get time from map (String "HH:mm")
            bool isNext = (prayerName == nextPrayer); // Check if this is the upcoming prayer

            // Skip rendering if time is missing for this prayer (shouldn't happen with standard API response)
            if (prayerTime == null) {
              return const SizedBox.shrink();
            }

            // Build the row for this prayer time
            return _buildPrayerTimeRow(
                name: prayerName,
                time24: prayerTime,
                isNext: isNext, // Pass highlighting flag
                provider: provider // Pass provider for formatting
            );
          }
      );
    }
  }

  // Builds a single row in the prayer times list
  Widget _buildPrayerTimeRow({
    required String name,
    required String? time24, // The "HH:mm" string from API
    required bool isNext, // Flag indicating if this is the next prayer
    required PrayerTimesProvider provider // Needed for time formatting
  }) {
    // Format the time based on user preference (12h/24h)
    final displayTime = time24 != null ? provider.formatTime(time24) : 'N/A';

    // Determine leading icon based on prayer type (example logic)
    IconData leadingIconData;
    Color iconColor = Colors.grey[600]!; // Default icon color
    Color textColor = Colors.black87; // Default text color

    if (['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].contains(name)) {
      leadingIconData = Icons.volume_up_outlined; // Placeholder for "Audible Notification"
      iconColor = Colors.teal[700]!;
    } else if (name == 'Imsak') {
      leadingIconData = Icons.timer_outlined; // Placeholder for Imsak
      iconColor = Colors.blueGrey[400]!;
    } else if (name == 'Sunrise'){
      leadingIconData = Icons.wb_sunny_outlined; // Placeholder for Sunrise
      iconColor = Colors.orange[600]!;
    } else {
      leadingIconData = Icons.watch_later_outlined; // Fallback
    }

    // Override colors if this is the next prayer
    if (isNext) {
      iconColor = Colors.white;
      textColor = Colors.white;
    }

    // Placeholder for trailing status icon (e.g., checkmark for 'done' - future feature)
    Widget? trailingWidget;
    // Example: Show checkmark only if it's the next prayer for now
    if (isNext) {
      trailingWidget = Icon(Icons.check_circle, color: Colors.white.withOpacity(0.9), size: 20);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        // Highlight background if it's the next prayer
        color: isNext ? Colors.green[600] : Colors.white,
        borderRadius: BorderRadius.circular(12.0), // Slightly more rounded corners
        boxShadow: [
          BoxShadow(
            color: isNext ? Colors.green.withOpacity(0.3) : Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Adjust padding
        dense: true, // Makes list items more compact
        // --- Leading Icon ---
        leading: Icon(leadingIconData, color: iconColor, size: 24), // Slightly larger icon
        // --- Title (Prayer Name) ---
        title: Text(
          name, // TODO: Consider adding Arabic name here if needed
          style: TextStyle(
            fontSize: 18, // Slightly larger font
            fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
        // --- Trailing (Time & Optional Status Icon) ---
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // Keep row compact
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              displayTime,
              style: TextStyle(
                fontSize: 17, // Slightly larger font
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFeatures: const [FontFeature.tabularFigures()], // Helps align numbers if font supports it
              ),
            ),
            if (trailingWidget != null) ...[
              const SizedBox(width: 12), // Space between time and icon
              trailingWidget,
            ]
          ],
        ),
        onTap: () {
          // TODO: Implement action on tap (e.g., toggle notification for this prayer)
          print("Tapped on $name");
        },
      ),
    );
  }

  // --- Builds the bottom section containing input fields ---
  Widget _buildBottomInputSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 16.0), // Add padding bottom
      decoration: BoxDecoration(
        color: Colors.white, // White background for input area
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2)), // Shadow at the top
        ],
        // Optional: Add rounded corners to top
        // borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Take only needed vertical space
        children: [
          // --- START: Definitions for methods called below ---
          _buildManualLocationInput(), // Address input field
          const SizedBox(height: 8),
          _buildRecentLocations(), // Recent search chips
          const SizedBox(height: 12),
          _buildCalculationMethodDropdown(), // Method selection dropdown
          // --- END: Definitions for methods called below ---
        ],
      ),
    );
  }


  // *** ADDING MISSING HELPER METHOD DEFINITIONS WITHIN THE CLASS ***

  // Widget for Manual Location Input Field & Button
  Widget _buildManualLocationInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30.0),
          border: Border.all(color: Colors.grey[300]!) // Add subtle border
        // boxShadow: [ BoxShadow(...) ], // Shadow removed as container has one now
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(Icons.search_outlined, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'Enter Address (e.g., Stockholm, SE)',
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchManualLocation(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined, color: Colors.green), // Changed icon
            tooltip: 'Search Location',
            onPressed: _searchManualLocation, // Calls method defined in state
          ),
        ],
      ),
    );
  }

  // Widget to display recent location chips
  Widget _buildRecentLocations() {
    // Uses Consumer to rebuild when recentLocations list changes in provider
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        if (provider.recentLocations.isEmpty) {
          return const SizedBox.shrink(); // Don't show anything if no recents
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0), // Add padding to title
              child: Text("Recent:", style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            Wrap( // Arrange chips horizontally, wrapping if needed
              spacing: 8.0, // Horizontal space between chips
              runSpacing: 4.0, // Vertical space between lines of chips
              children: provider.recentLocations.map((location) {
                return ActionChip(
                  avatar: Icon(Icons.history, size: 18, color: Colors.teal[800]), // Themed icon
                  label: Text(location),
                  backgroundColor: Colors.teal.withOpacity(0.1), // Lighter background
                  labelStyle: TextStyle(color: Colors.teal[900], fontSize: 13), // Themed text
                  onPressed: () {
                    _locationController.text = location; // Populate search field
                    _searchManualLocation(); // Trigger search
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces tap area padding
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Adjust padding
                  side: BorderSide(color: Colors.teal.withOpacity(0.3)), // Subtle border
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // Calculation Method Dropdown Widget
  Widget _buildCalculationMethodDropdown() {
    // Use Consumer to get provider instance and rebuild when method or loading state changes
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey.shade300), // Subtle border
            // boxShadow: [ BoxShadow(...) ], // Optional shadow
          ),
          child: DropdownButtonHideUnderline( // Remove default underline
            child: DropdownButton<int>(
              value: provider.calculationMethod, // Current selected value from provider
              isExpanded: true, // Make dropdown fill available width
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]), // Standard dropdown icon
              hint: const Text("Calculation Method"), // Placeholder if value were null
              items: provider.availableCalculationMethods.entries.map((entry) {
                // Create a dropdown item for each method in the provider's map
                return DropdownMenuItem<int>(
                  value: entry.key, // The method ID (int)
                  child: Text(
                    entry.value, // The method name (String)
                    overflow: TextOverflow.ellipsis, // Prevent long names breaking UI
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              // Disable dropdown interaction while loading data
              onChanged: provider.isLoading ? null : (int? newValue) {
                // When user selects a new item
                if (newValue != null) {
                  // Call provider method to update state and save preference
                  provider.setCalculationMethod(newValue);
                  // Show brief confirmation message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Method set: ${provider.availableCalculationMethods[newValue]}'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  // Note: We don't automatically refetch times here, user needs to refresh manually
                }
              },
            ),
          ),
        );
      },
    );
  }


} // End of _HomeScreenState class