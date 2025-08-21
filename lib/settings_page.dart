import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'prayer_times_provider.dart';

class SettingsPage extends StatelessWidget {
  final TextEditingController _locationController = TextEditingController();

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
          // Location Section
          _buildSectionHeader('Location Settings'),
          _buildLocationInput(context),
          
          // Calculation Method Section
          _buildSectionHeader('Prayer Calculation Method'),
          _buildCalculationMethodSelector(context),
          
          // About Section
          _buildSectionHeader('About'),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.teal[700],
        ),
      ),
    );
  }

  Widget _buildLocationInput(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Enter City or Address',
                hintText: 'e.g., London, UK',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.my_location),
                  label: Text('Use GPS'),
                  onPressed: () {
                    Provider.of<PrayerTimesProvider>(context, listen: false)
                        .fetchTimesByGps();
                    Navigator.pop(context);
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text('Search'),
                  onPressed: () {
                    if (_locationController.text.isNotEmpty) {
                      Provider.of<PrayerTimesProvider>(context, listen: false)
                          .fetchTimesByAddress(_locationController.text);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationMethodSelector(BuildContext context) {
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculation Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: provider.calculationMethod,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: provider.availableCalculationMethods.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.setCalculationMethod(value);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.code, color: Colors.white),
              ),
              title: Text('Developer'),
              subtitle: Text('Mohammad Dib'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Version'),
              subtitle: Text('1.0.0'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.api),
              title: Text('Prayer Times API'),
              subtitle: Text('Al Adhan API'),
            ),
          ],
        ),
      ),
    );
  }
}
