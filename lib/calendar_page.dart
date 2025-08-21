import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'prayer_times_provider.dart';

class DayPrayerTimes {
  final DateTime gregorianDate;
  final HijriCalendar hijriDate;
  final Map<String, dynamic>? prayerTimes;

  DayPrayerTimes({
    required this.gregorianDate,
    required this.hijriDate,
    this.prayerTimes,
  });
}

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with SingleTickerProviderStateMixin {
  late List<DayPrayerTimes> _monthData;
  late HijriCalendar _selectedHijriDate;
  late DateTime _selectedGregorianDate;
  List<HijriCalendar> _monthDays = [];

  // Hijri month names
  final List<String> _hijriMonths = [
    'Muharram', 'Safar', 'Rabi\' al-Awwal', 'Rabi\' al-Thani',
    'Jumada al-Ula', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
    'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
  ];

  String getHijriMonthName(int month) {
    if (month < 1 || month > 12) return '';
    return _hijriMonths[month - 1];
  }
  
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _selectedHijriDate = HijriCalendar.now();
    _selectedGregorianDate = DateTime.now();
    _generateMonthData();
    _generateMonthDays();

    // Start the initial animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generateMonthData() {
    _monthData = [];
    _monthDays = [];
    
    // Generate data for Hijri calendar
    HijriCalendar firstDay = HijriCalendar.fromDate(DateTime.now());
    firstDay.hYear = _selectedHijriDate.hYear;
    firstDay.hMonth = _selectedHijriDate.hMonth;
    firstDay.hDay = 1;
    
    // Calculate the number of days in the current Hijri month (typically 29 or 30)
    int daysInHijriMonth = _selectedHijriDate.hMonth == 12 
        ? HijriCalendar.fromDate(firstDay.hijriToGregorian(firstDay.hYear + 1, 1, 1)).hDay - 1
        : HijriCalendar.fromDate(firstDay.hijriToGregorian(firstDay.hYear, firstDay.hMonth + 1, 1)).hDay - 1;
    
    for (int i = 0; i < daysInHijriMonth; i++) {
      HijriCalendar day = HijriCalendar()
        ..hYear = firstDay.hYear
        ..hMonth = firstDay.hMonth
        ..hDay = i + 1;
      _monthDays.add(day);
      
      // Convert to Gregorian for prayer times
      DateTime gregDate = day.hijriToGregorian(day.hYear, day.hMonth, day.hDay);
      _monthData.add(DayPrayerTimes(
        gregorianDate: gregDate,
        hijriDate: day,
      ));
    }
  }

  void _generateMonthDays() {
    if (_monthDays.isEmpty) {
      HijriCalendar firstDay = HijriCalendar.fromDate(DateTime.now());
      firstDay.hYear = _selectedHijriDate.hYear;
      firstDay.hMonth = _selectedHijriDate.hMonth;
      firstDay.hDay = 1;
      
      int daysInHijriMonth = _selectedHijriDate.hMonth == 12 
          ? HijriCalendar.fromDate(firstDay.hijriToGregorian(firstDay.hYear + 1, 1, 1)).hDay - 1
          : HijriCalendar.fromDate(firstDay.hijriToGregorian(firstDay.hYear, firstDay.hMonth + 1, 1)).hDay - 1;
      
      for (int i = 0; i < daysInHijriMonth; i++) {
        _monthDays.add(HijriCalendar()
          ..hYear = firstDay.hYear
          ..hMonth = firstDay.hMonth
          ..hDay = i + 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prayer Calendar'),
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
      body: Column(
        children: [
          _buildCalendarHeader(),
          Expanded(
            child: Card(
              margin: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Monthly Prayer Schedule',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(child: _buildMonthlyTable()),
                ],
              ),
            ),
          ),
          // Removed per-day panel in favor of full monthly table
        ],
      ),
    );
  }

  Future<void> _goToPreviousMonth() async {
    // Start reverse animation
    await _animationController.reverse();
    
    // Update Hijri date
    _selectedHijriDate = HijriCalendar()
      ..hYear = _selectedHijriDate.hMonth == 1 
          ? _selectedHijriDate.hYear - 1 
          : _selectedHijriDate.hYear
      ..hMonth = _selectedHijriDate.hMonth == 1 
          ? 12 
          : _selectedHijriDate.hMonth - 1
      ..hDay = 1;

    // Convert Hijri to Gregorian for synchronization
    DateTime newGregorianDate = _selectedHijriDate.hijriToGregorian(
      _selectedHijriDate.hYear,
      _selectedHijriDate.hMonth,
      1
    );

    // Update Gregorian dates
    _selectedGregorianDate = newGregorianDate;

    // Forward animation for new content
    await _animationController.forward();
  }

  Future<void> _goToNextMonth() async {
    // Start reverse animation
    await _animationController.reverse();
    
    // Update Hijri date
    _selectedHijriDate = HijriCalendar()
      ..hYear = _selectedHijriDate.hMonth == 12 
          ? _selectedHijriDate.hYear + 1 
          : _selectedHijriDate.hYear
      ..hMonth = _selectedHijriDate.hMonth == 12 
          ? 1 
          : _selectedHijriDate.hMonth + 1
      ..hDay = 1;

    // Convert Hijri to Gregorian for synchronization
    DateTime newGregorianDate = _selectedHijriDate.hijriToGregorian(
      _selectedHijriDate.hYear,
      _selectedHijriDate.hMonth,
      1
    );

    // Update Gregorian dates
    _selectedGregorianDate = newGregorianDate;

    // Forward animation for new content
    await _animationController.forward();
  }

  Future<void> _showMonthYearPicker() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        int selectedYear = _selectedHijriDate.hYear;
        int selectedMonth = _selectedHijriDate.hMonth;

        return AlertDialog(
          title: Text('Select Month & Year', style: TextStyle(color: Colors.teal[700])),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        setState(() => selectedYear--);
                      },
                    ),
                    Text(
                      selectedYear.toString(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() => selectedYear++);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                // Month grid
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  children: List.generate(12, (index) {
                    final month = index + 1;
                    final isSelected = month == selectedMonth;
                    return InkWell(
                      onTap: () {
                        setState(() => selectedMonth = month);
                      },
                      child: Container(
                        margin: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal.withOpacity(0.2) : null,
                          border: Border.all(
                            color: isSelected ? Colors.teal : Colors.transparent,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            getHijriMonthName(month),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop({
                  'year': selectedYear,
                  'month': selectedMonth,
                });
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      await _animationController.reverse();
      
      _selectedHijriDate = HijriCalendar()
        ..hYear = result['year']!
        ..hMonth = result['month']!
        ..hDay = 1;

      _selectedGregorianDate = _selectedHijriDate.hijriToGregorian(
        _selectedHijriDate.hYear,
        _selectedHijriDate.hMonth,
        1
      );

      setState(() {
        _generateMonthData();
        _generateMonthDays();
      });

      await _animationController.forward();
    }
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () async {
              await _goToPreviousMonth();
              setState(() {
                _generateMonthData();
                _generateMonthDays();
              });
            },
          ),
          InkWell(
            onTap: _showMonthYearPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  children: [
                    Text(
                      '${_selectedHijriDate.hDay} ${_selectedHijriDate.getLongMonthName()} ${_selectedHijriDate.hYear}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('d MMMM yyyy').format(_selectedGregorianDate),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Icon(Icons.calendar_month, color: Colors.grey[600]),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () async {
              await _goToNextMonth();
              setState(() {
                _generateMonthData();
                _generateMonthDays();
              });
            },
          ),
        ],
      ),
    );
  }

  // Removed unused day header builder from previous grid view implementation

  Widget _buildMonthlyTable() {
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, child) {
        final year = _selectedGregorianDate.year;
        final month = _selectedGregorianDate.month;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final dates = List.generate(daysInMonth, (i) => DateTime(year, month, i + 1));

        final future = Future.wait(dates.map((d) async {
          final times = await provider.getPrayerTimesForDate(d);
          final hijri = HijriCalendar.fromDate(d);
          return DayPrayerTimes(gregorianDate: d, hijriDate: hijri, prayerTimes: times);
        }));

        return FutureBuilder<List<DayPrayerTimes>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Failed to load month data', style: TextStyle(color: Colors.red)),
                ),
              );
            }
            final rows = snapshot.data ?? [];

            final headerStyle = const TextStyle(fontWeight: FontWeight.bold);
            Text _cell(String text, {TextStyle? style}) => Text(text, overflow: TextOverflow.ellipsis, maxLines: 1, style: style);

            final tableRows = <TableRow>[
              TableRow(
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.06)),
                children: [
                  for (final h in ['Date','Day','Hijri','Fajr','Shurouq','Dhuhr','Asr','Maghrib','Isha'])
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(h, style: headerStyle)),
                ],
              ),
              ...rows.map((e) {
                final d = e.gregorianDate;
                final h = e.hijriDate;
                final t = e.prayerTimes;
                String fmt(String? raw, String name) {
                  final s = raw?.toString();
                  if (s == null || s.isEmpty) return '-';
                  return provider.formatTime(s, prayerName: name);
                }
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(DateFormat('d').format(d))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(DateFormat('EEE').format(d))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell('${h.hDay} ${h.getLongMonthName()}')),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Fajr'], 'Fajr'))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Sunrise'], 'Sunrise'))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Dhuhr'], 'Dhuhr'))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Asr'], 'Asr'))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Maghrib'], 'Maghrib'))),
                    Padding(padding: const EdgeInsets.all(8.0), child: _cell(fmt(t?['Isha'], 'Isha'))),
                  ],
                );
              }),
            ];

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: SingleChildScrollView(
                  child: Table(
                    border: TableBorder.all(color: Colors.grey.withOpacity(0.25), width: 1),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(56), // Date
                      1: FixedColumnWidth(56), // Day
                      2: FixedColumnWidth(140), // Hijri
                      3: FixedColumnWidth(80),
                      4: FixedColumnWidth(80),
                      5: FixedColumnWidth(80),
                      6: FixedColumnWidth(80),
                      7: FixedColumnWidth(80),
                      8: FixedColumnWidth(80),
                    },
                    children: tableRows,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
