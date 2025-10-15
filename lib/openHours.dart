import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flock/app_colors.dart'; // Import AppColors for primary color

/// Top-level day schedule model (needed for generics)
class DaySchedule {
  final bool enabled;
  final TimeOfDay open;
  final TimeOfDay close;
  const DaySchedule({
    required this.enabled,
    required this.open,
    required this.close,
  });
}

class OpenHoursScreen extends StatefulWidget {
  const OpenHoursScreen({super.key});

  @override
  State<OpenHoursScreen> createState() => _OpenHoursScreenState();
}

class _OpenHoursScreenState extends State<OpenHoursScreen> {
  List<Map<String, dynamic>> _venues = [];
  Map<String, dynamic>? _selectedVenue;

  final List<Map<String, dynamic>> _baseDays = [
    {
      "day": "Mon",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Tue",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Wed",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Thu",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Fri",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Sat",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
    {
      "day": "Sun",
      "isOpen": false,
      "openTime": "",
      "closeTime": "",
      "updated": false,
    },
  ];

  List<Map<String, dynamic>> _days = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Overnight-aware “open now” UI
  bool _isOpenNow = false;
  String _openNowLabel = '—';

  @override
  void initState() {
    super.initState();
    _days = _baseDays.map((e) => Map<String, dynamic>.from(e)).toList();
    _fetchVenues();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchVenues() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
        _isLoading = false;
      });
      return;
    }
    final url = Uri.parse('https://api.getflock.io/api/vendor/venues');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> venueData = data['data'];
          final loadedVenues =
              venueData
                  .map<Map<String, dynamic>>(
                    (v) => {
                      'id': v['id'],
                      'name': v['name'] ?? 'Unnamed Venue',
                    },
                  )
                  .toList();
          setState(() {
            _venues = loadedVenues;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load venues.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: Unable to fetch venues.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }

    if (_venues.isNotEmpty && _selectedVenue == null) {
      setState(() {
        _selectedVenue = _venues.first;
        _fetchOpeningHours(_selectedVenue!['id']);
      });
    }
  }

  Future<void> _fetchOpeningHours(int venueId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
        _isLoading = false;
      });
      return;
    }
    final url = Uri.parse(
      'https://api.getflock.io/api/vendor/venues/$venueId/opening-hours',
    );
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> hoursData = data['data'];
          const dayMap = {
            "Monday": "Mon",
            "Tuesday": "Tue",
            "Wednesday": "Wed",
            "Thursday": "Thu",
            "Friday": "Fri",
            "Saturday": "Sat",
            "Sunday": "Sun",
          };

          final updatedDays =
              _baseDays.map((e) => Map<String, dynamic>.from(e)).toList();

          // Use status==1 as active; ignore "closed" field from payload
          for (final item in hoursData) {
            final serverStartDay = (item['start_day'] ?? '').toString();
            final localDay = dayMap[serverStartDay] ?? serverStartDay;
            final openTime = (item['start_time'] ?? '').toString();
            final closeTime = (item['end_time'] ?? '').toString();
            final isActive = _toInt(item['status']) == 1;

            final idx = updatedDays.indexWhere((d) => d['day'] == localDay);
            if (idx != -1) {
              updatedDays[idx] = {
                "day": localDay,
                "isOpen": isActive,
                "openTime": _convertTo12HrFormat(
                  openTime.isEmpty ? "12:00 AM" : openTime,
                ),
                "closeTime": _convertTo12HrFormat(
                  closeTime.isEmpty ? "12:00 AM" : closeTime,
                ),
                "updated": false,
              };
            }
          }

          setState(() {
            _days = updatedDays;
          });

          _recomputeOpenNow();
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load opening hours.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: Unable to fetch hours.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _saveOpeningHours() async {
    if (_selectedVenue == null) {
      setState(() => _errorMessage = 'Please select a venue first.');
      return;
    }
    final venueId = _selectedVenue!['id'];
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
        _isLoading = false;
      });
      return;
    }

    const dayMap = {
      "Mon": "Monday",
      "Tue": "Tuesday",
      "Wed": "Wednesday",
      "Thu": "Thursday",
      "Fri": "Friday",
      "Sat": "Saturday",
      "Sun": "Sunday",
    };

    final url = Uri.parse(
      'https://api.getflock.io/api/vendor/venues/$venueId/opening-hours',
    );
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    for (int i = 0; i < _days.length; i++) {
      final d = _days[i];
      final serverDay = dayMap[d["day"]] ?? d["day"];
      final openT = d["isOpen"] ? d["openTime"].toString() : "00:00";
      final closeT = d["isOpen"] ? d["closeTime"].toString() : "00:00";
      final status = d["isOpen"] ? "1" : "0";

      request.fields['opening_hours[$i][day]'] = serverDay;
      request.fields['opening_hours[$i][start_time]'] = openT;
      request.fields['opening_hours[$i][end_time]'] = closeT;
      request.fields['opening_hours[$i][status]'] = status;
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Hours updated successfully!',
                style: Theme.of(context).snackBarTheme.contentTextStyle,
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            for (var day in _days) {
              if (day['isOpen']) day['updated'] = true;
            }
          });
          _recomputeOpenNow();
        } else {
          setState(
            () => _errorMessage = data['message'] ?? 'Failed to update hours.',
          );
        }
      } else {
        setState(
          () =>
              _errorMessage = 'Error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  // ----------------- Time / Overnight Helpers -----------------

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  // Parse "hh:mm AM/PM" or "HH:mm" safely into TimeOfDay.
  TimeOfDay _parseFlexible(String s) {
    final str = (s.trim()).toUpperCase();
    try {
      if (str.contains('AM') || str.contains('PM')) {
        final parts = str.split(RegExp(r'\s+'));
        final hm = parts[0].split(':');
        int h = int.parse(hm[0]);
        int m = int.parse(hm[1]);
        final p = parts[1];
        if (p == 'AM') {
          if (h == 12) h = 0;
        } else {
          if (h != 12) h += 12;
        }
        return TimeOfDay(hour: h % 24, minute: m % 60);
      }
      if (str == "00:00") return const TimeOfDay(hour: 0, minute: 0);
      final parts = str.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]) % 24,
        minute: int.parse(parts[1]) % 60,
      );
    } catch (_) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Convert _days (Mon..Sun) to weekly schedules
  List<DaySchedule> _buildWeekFromDays(List<Map<String, dynamic>> days) {
    const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return order.map((d) {
      final row = days.firstWhere(
        (e) => e['day'] == d,
        orElse:
            () => {
              'isOpen': false,
              'openTime': '12:00 AM',
              'closeTime': '12:00 AM',
            },
      );
      final enabled = (row['isOpen'] ?? false) == true;
      final open = _parseFlexible('${row['openTime'] ?? '12:00 AM'}');
      final close = _parseFlexible('${row['closeTime'] ?? '12:00 AM'}');
      return DaySchedule(enabled: enabled, open: open, close: close);
    }).toList();
  }

  /// Overnight-aware weekly check (Mon=0..Sun=6)
  bool _isOpenNowWeekly(List<DaySchedule> week, {DateTime? now}) {
    assert(week.length == 7);
    final dt = (now ?? DateTime.now()).toLocal();
    final todayIdx = dt.weekday - 1; // Mon=1..Sun=7 -> 0..6
    final yIdx = (todayIdx - 1 + 7) % 7;
    final n = dt.hour * 60 + dt.minute;

    // Today
    final t = week[todayIdx];
    if (t.enabled) {
      final o = _mins(t.open);
      final c = _mins(t.close);
      if (c > o) {
        if (n >= o && n < c) return true; // same-day
      } else if (c != o) {
        if (n >= o) return true; // overnight tonight
      }
    }

    // Early morning spill from yesterday
    final y = week[yIdx];
    if (y.enabled) {
      final oy = _mins(y.open);
      final cy = _mins(y.close);
      if (cy <= oy && cy != oy) {
        if (n < cy) return true;
      }
    }

    return false;
  }

  /// Current open range label if open; otherwise “Closed now”
  String _currentOpenRangeLabel(List<DaySchedule> week, {DateTime? now}) {
    final dt = (now ?? DateTime.now()).toLocal();
    final todayIdx = dt.weekday - 1;
    final yIdx = (todayIdx - 1 + 7) % 7;
    final n = dt.hour * 60 + dt.minute;

    final t = week[todayIdx];
    if (t.enabled) {
      final o = _mins(t.open);
      final c = _mins(t.close);
      if (c > o && n >= o && n < c) {
        return 'Open ${_formatTo12Hour(t.open)}–${_formatTo12Hour(t.close)}';
      }
      if (c <= o && n >= o) {
        return 'Open ${_formatTo12Hour(t.open)}–${_formatTo12Hour(t.close)}';
      }
    }

    final y = week[yIdx];
    if (y.enabled) {
      final oy = _mins(y.open);
      final cy = _mins(y.close);
      if (cy <= oy && n < cy) {
        return 'Open ${_formatTo12Hour(y.open)}–${_formatTo12Hour(y.close)}';
      }
    }

    return 'Closed now';
  }

  void _recomputeOpenNow() {
    final week = _buildWeekFromDays(_days);
    final openNow = _isOpenNowWeekly(week);
    final label = openNow ? _currentOpenRangeLabel(week) : 'Closed now';
    setState(() {
      _isOpenNow = openNow;
      _openNowLabel = label;
    });
  }

  // ----------------- Existing formatters -----------------

  String _convertTo12HrFormat(String time24) {
    try {
      final lower = time24.toLowerCase();
      if (lower.contains('am') || lower.contains('pm')) return time24;
      if (time24 == "00:00") return "12:00 AM";
      final parts = time24.split(":");
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = minute.toString().padLeft(2, '0');
      return "$hourStr:$minStr $period";
    } catch (_) {
      return "12:00 AM";
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final hhmm = parts[0].split(':');
      int hour = int.parse(hhmm[0]);
      final minute = int.parse(hhmm[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String _formatTo12Hour(TimeOfDay time) {
    final hourStr = time.hourOfPeriod.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hourStr:$minStr $period';
  }

  // ----------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: Image.asset(
                            'assets/back_updated.png',
                            height: 40,
                            width: 34,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              "Open Hours",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),

                  // Open Now chip
                  if (_openNowLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: (_isOpenNow
                                  ? AppColors.primary.withOpacity(0.10)
                                  : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest)
                              .withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _isOpenNow
                                    ? AppColors.primary.withOpacity(0.55)
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isOpenNow ? Icons.check_circle : Icons.schedule,
                              size: 18,
                              color:
                                  _isOpenNow
                                      ? AppColors.primary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _openNowLabel,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: _showVenueSelectionDialog,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedVenue?['name'] ?? 'Select a venue',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: SingleChildScrollView(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(
                    height: 520,
                    child: ListView.builder(
                      itemCount: _days.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final dayInfo = _days[index];
                        return _buildDayRow(dayInfo, index);
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saveOpeningHours,
                        style: Theme.of(context).elevatedButtonTheme.style,
                        child: Text(
                          "Save",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Stack(
              children: [
                Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.14),
                ),
                Container(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
                  child: Center(
                    child: Image.asset(
                      'assets/Bird_Full_Eye_Blinking.gif',
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }

  void _showVenueSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            "Select Venue",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 250,
            child: ListView.builder(
              itemCount: _venues.length,
              itemBuilder: (context, index) {
                final venue = _venues[index];
                final isSelected = _selectedVenue?['id'] == venue['id'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVenue = venue;
                      _fetchOpeningHours(venue['id']);
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    color:
                        isSelected
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue['name'] ?? 'Unnamed Venue',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayRow(Map<String, dynamic> dayInfo, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                dayInfo["day"],
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 16),
              ),
            ),
            SizedBox(
              width: 60,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _days[index]["isOpen"] = !_days[index]["isOpen"];
                    if (!_days[index]["isOpen"])
                      _days[index]["updated"] = false;
                    _recomputeOpenNow();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        dayInfo["isOpen"]
                            ? AppColors.primary
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dayInfo["isOpen"] ? "On" : "Off",
                    style: TextStyle(
                      color:
                          dayInfo["isOpen"]
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayInfo["openTime"],
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  Text(" - ", style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    dayInfo["closeTime"],
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.access_time,
                color:
                    dayInfo["isOpen"]
                        ? AppColors.primary
                        : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.4),
              ),
              onPressed:
                  dayInfo["isOpen"]
                      ? () async {
                        await _showDayDialog(dayInfo["day"], index);
                        _recomputeOpenNow();
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayDialog(String day, int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        String tempOpen = _days[index]["openTime"];
        String tempClose = _days[index]["closeTime"];
        bool applyToAllDays = false;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(day, style: Theme.of(context).textTheme.titleMedium),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _parseTimeOfDay(tempOpen),
                          initialEntryMode: TimePickerEntryMode.input,
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  hourMinuteTextColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  dialHandColor: AppColors.primary,
                                  entryModeIconColor: AppColors.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            tempOpen = _formatTo12Hour(picked);
                          });
                        }
                      },
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: Text(
                        "Set Opening Time: $tempOpen",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _parseTimeOfDay(tempClose),
                          initialEntryMode: TimePickerEntryMode.input,
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  hourMinuteTextColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  dialHandColor: AppColors.primary,
                                  entryModeIconColor: AppColors.primary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setStateDialog(() {
                            tempClose = _formatTo12Hour(picked);
                          });
                        }
                      },
                      style: Theme.of(context).elevatedButtonTheme.style,
                      child: Text(
                        "Set Closing Time: $tempClose",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: applyToAllDays,
                        onChanged: (bool? value) {
                          setStateDialog(() {
                            applyToAllDays = value ?? false;
                          });
                        },
                        activeColor: AppColors.primary,
                        checkColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                      Text(
                        "Apply to all days",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    "Cancel",
                    style: Theme.of(context).textButtonTheme.style?.textStyle
                        ?.resolve({})
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'tempOpen': tempOpen,
                      'tempClose': tempClose,
                      'applyToAllDays': applyToAllDays,
                      'index': index,
                    });
                  },
                  style: Theme.of(context).elevatedButtonTheme.style,
                  child: Text(
                    "OK",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (result['applyToAllDays'] == true) {
          for (int i = 0; i < _days.length; i++) {
            _days[i]["openTime"] = result['tempOpen'];
            _days[i]["closeTime"] = result['tempClose'];
            _days[i]["isOpen"] = true;
            _days[i]["updated"] = false;
          }
        } else {
          _days[index]["openTime"] = result['tempOpen'];
          _days[index]["closeTime"] = result['tempClose'];
          _days[index]["isOpen"] = true;
          _days[index]["updated"] = false;
        }
      });
    }
  }
}
