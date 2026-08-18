import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../utils/auth_service.dart';
import '../utils/dummy_data_service.dart';
import 'leave_application.dart';

class DailyAttendancePage extends StatefulWidget {
  const DailyAttendancePage({super.key});

  @override
  State<DailyAttendancePage> createState() => _DailyAttendancePageState();
}

class _DailyAttendancePageState extends State<DailyAttendancePage> {
  String selectedYear = DateTime.now().year.toString();
  String selectedMonth = DateTime.now().month.toString();
  String? empPaycode;
  bool isLoading = false;
  List<AttendanceRecord> attendanceData = [];
  Map<String, dynamic>? leaveBalance;
  Map<String, dynamic>? leaveAvail;

  // Scroll controllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _stickyHScrollController = ScrollController();
  bool _isHeaderSticky = false;

  // Height of the top section (leave balance + filters) — used as sticky threshold
  // We use a GlobalKey to measure it at runtime
  final GlobalKey _topSectionKey = GlobalKey();
  double _topSectionHeight = 0;

  final AuthService _authService = AuthService();
  
  // Generate year list including current year and previous years
  List<String> get yearList {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => (currentYear - index).toString());
  }
  
  // Generate month list
  List<String> get monthList {
    return List.generate(12, (index) => (index + 1).toString());
  }
  
  // Get month name for display
  String getMonthName(String monthNumber) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    try {
      final index = int.parse(monthNumber) - 1;
      if (index >= 0 && index < monthNames.length) {
        return monthNames[index];
      }
    } catch (e) {
      debugPrint('Error parsing month number: $monthNumber');
    }
    
    return 'January'; // Default fallback
  }
  
  // Format time duration from hours and minutes to "X hrs, Y mins" format
  String formatDuration(Map<String, dynamic> duration) {
    final hours = duration['hours'] ?? 0;
    final minutes = duration['minutes'] ?? 0;
    if (hours == 0 && minutes == 0) return '--';
    return '$hours hrs, $minutes mins';
  }
  
  // Format date to DD-MMM-YYYY format (01-Dec-2025)
  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = monthNames[date.month - 1];
      final year = date.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      debugPrint('Error parsing date: $dateStr');
      return dateStr;
    }
  }
  
  // Get full day name
  String getFullDayName(String? dayName) {
    if (dayName == null || dayName.isEmpty) return '--';
    
    final dayMap = {
      'Mon': 'Monday',
      'Tue': 'Tuesday', 
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };
    
    // If it's already a full name, return it
    if (dayName.length > 3) return dayName;
    
    // Otherwise, convert from short form
    return dayMap[dayName] ?? dayName;
  }
  
  // Generate dummy attendance records for test user
  List<AttendanceRecord> _generateDummyAttendanceRecords() {
    final List<AttendanceRecord> records = [];
    final year = int.parse(selectedYear);
    final month = int.parse(selectedMonth);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1];
      
      // Skip future dates
      if (date.isAfter(DateTime.now())) continue;
      
      String status = 'Present';
      String inTime = '--';
      String outTime = '--';
      String totalHours = '0 hrs, 0 mins';
      String shift = 'General';
      
      // Weekend logic
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        if (day % 7 == 0) { // Occasional weekend work
          status = 'Present';
          inTime = '10:00';
          outTime = '14:00';
          totalHours = '4 hrs, 0 mins';
        } else {
          status = 'Week Off';
        }
      }
      // Holiday logic
      else if (day == 15 || day == 26) {
        status = 'Holiday';
      }
      // Leave logic
      else if (day == 8 || day == 22) {
        status = 'Leave';
      }
      // Regular working day
      else {
        final inHour = 8 + (day % 2); // Alternate between 8 and 9
        final inMinute = 30 + (day % 30); // Vary minutes
        final outHour = 17 + (day % 2); // Alternate between 17 and 18
        final outMinute = 30 + (day % 30); // Vary minutes
        
        inTime = '${inHour.toString().padLeft(2, '0')}:${inMinute.toString().padLeft(2, '0')}';
        outTime = '${outHour.toString().padLeft(2, '0')}:${outMinute.toString().padLeft(2, '0')}';
        
        final workHours = outHour - inHour;
        final workMinutes = outMinute - inMinute;
        totalHours = '${workHours}h ${workMinutes}m';
        
        status = 'Present';
      }
      
      records.add(AttendanceRecord(
        date: formatDate(date.toIso8601String()),
        shift: shift,
        inTime: inTime,
        outTime: outTime,
        totalHours: totalHours,
        lateHours: '0 hrs, 0 mins',
        earlyOut: '0 hrs, 0 mins',
        extraHours: '0 hrs, 0 mins',
        day: dayName,
        status: status,
      ));
    }
    
    return records.reversed.toList(); // Show latest first
  }
  
  // Parse "X hrs, Y mins" string to total minutes
  int _parseDurationToMinutes(String duration) {
    if (duration == '--' || duration.isEmpty || duration == '0 hrs, 0 mins') return 0;
    try {
      final hrsMatch = RegExp(r'(\d+)\s*hrs?').firstMatch(duration);
      final minsMatch = RegExp(r'(\d+)\s*mins?').firstMatch(duration);
      final hrs = hrsMatch != null ? int.parse(hrsMatch.group(1)!) : 0;
      final mins = minsMatch != null ? int.parse(minsMatch.group(1)!) : 0;
      return hrs * 60 + mins;
    } catch (e) {
      return 0;
    }
  }

  // Format total minutes to "X hrs, Y mins (Z mins)" like the image
  String _formatTotalMinutes(int totalMins) {
    if (totalMins == 0) return '--';
    final hrs = totalMins ~/ 60;
    final mins = totalMins % 60;
    return '$hrs hrs, $mins mins ($totalMins mins)';
  }

  // Compute column totals from attendanceData
  Map<String, int> _computeTotals() {
    int totalHoursMins = 0;
    int lateHoursMins = 0;
    int earlyOutMins = 0;
    int extraHoursMins = 0;

    for (final record in attendanceData) {
      totalHoursMins += _parseDurationToMinutes(record.totalHours);
      lateHoursMins += _parseDurationToMinutes(record.lateHours);
      earlyOutMins += _parseDurationToMinutes(record.earlyOut);
      extraHoursMins += _parseDurationToMinutes(record.extraHours);
    }

    return {
      'totalHours': totalHoursMins,
      'lateHours': lateHoursMins,
      'earlyOut': earlyOutMins,
      'extraHours': extraHoursMins,
    };
  }

  // Get status display text and color
  Map<String, dynamic> getStatusInfo(String status) {
    switch (status) {
      case 'P':
        return {'text': 'Present', 'color': Colors.green};
      case 'WO':
        return {'text': 'Week Off', 'color': Colors.orange};
      case 'WO*':
        return {'text': 'Week Off*', 'color': Colors.orange};
      case 'MS':
        return {'text': 'Miss Punch', 'color': Colors.orange};
      case 'A':
        return {'text': 'Absent', 'color': Colors.red};
      case 'L':
        return {'text': 'Leave', 'color': Colors.blue};
      case 'H':
        return {'text': 'Holiday', 'color': Colors.purple};
      default:
        return {'text': status, 'color': Colors.grey};
    }
  }
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _horizontalScrollController.addListener(() {
      setState(() {}); // rebuild rows + sticky header on horizontal scroll
      // Sync sticky header scroll position after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_stickyHScrollController.hasClients &&
            _stickyHScrollController.positions.length == 1 &&
            _horizontalScrollController.hasClients &&
            _horizontalScrollController.positions.length == 1) {
          final offset = _horizontalScrollController.offset;
          if ((_stickyHScrollController.offset - offset).abs() > 0.5) {
            _stickyHScrollController.jumpTo(offset);
          }
        }
      });
    });
    _verticalScrollController.addListener(() {
      // Measure top section height after first frame
      if (_topSectionHeight == 0) {
        final ctx = _topSectionKey.currentContext;
        if (ctx != null) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box != null) _topSectionHeight = box.size.height;
        }
      }
      final sticky = _verticalScrollController.offset >= _topSectionHeight;
      if (sticky != _isHeaderSticky) {
        setState(() => _isHeaderSticky = sticky);
      }
    });
    // Measure top section height after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _topSectionKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          setState(() => _topSectionHeight = box.size.height);
        }
      }
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _stickyHScrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    try {
      empPaycode = await _authService.getEmployeePaycode();
      
      if (empPaycode != null) {
        debugPrint('📱 Loaded employee paycode: $empPaycode');
        // Load initial data
        _fetchAttendanceData();
      } else {
        debugPrint('❌ No employee paycode found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee ID not found. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }
  
  Future<void> _fetchAttendanceData() async {
    if (empPaycode == null) return;
    
    setState(() {
      isLoading = true;
    });
    
    try {
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy daily attendance data');
        
        // Generate dummy attendance records for selected month/year
        final dummyRecords = _generateDummyAttendanceRecords();
        final dummyLeaveBalance = {
          'bel': 10.0,
          'bcl': 9.0,
          'bsl': 8.0,
          'bml': 0.0,
        };
        final dummyLeaveAvail = {
          'used_el': 5.0,
          'used_sl': 2.0,
          'used_cl': 1.0,
          'used_ml': 0.0,
        };
        
        debugPrint('📊 Generated ${dummyRecords.length} dummy attendance records');
        debugPrint('📊 Leave balance: EL=${dummyLeaveBalance['opening_el']}, SL=${dummyLeaveBalance['opening_sl']}, CL=${dummyLeaveBalance['opening_cl']}');
        debugPrint('📊 Leave used: EL=${dummyLeaveAvail['used_el']}, SL=${dummyLeaveAvail['used_sl']}, CL=${dummyLeaveAvail['used_cl']}');
        
        // Simulate loading delay
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {
          attendanceData = dummyRecords;
          leaveBalance = dummyLeaveBalance;
          leaveAvail = dummyLeaveAvail;
          isLoading = false;
        });
        
        // Re-measure top section height after leave balance loads
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _topSectionKey.currentContext;
          if (ctx != null) {
            final box = ctx.findRenderObject() as RenderBox?;
            if (box != null) setState(() => _topSectionHeight = box.size.height);
          }
        });
        
        debugPrint('✅ Dummy attendance data loaded - UI updated with ${attendanceData.length} records');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Loaded ${dummyRecords.length} attendance records'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      final endpoint = '/ess/daily-attendance/?json=1&emp_paycode=$empPaycode&year=$selectedYear&month=$selectedMonth';
      debugPrint('🔗 Fetching attendance data from: $endpoint');
      
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Attendance data fetched successfully');
        
        // Parse the response data
        if (responseData['data'] != null) {
          final List<dynamic> dataList = responseData['data'];
          final List<AttendanceRecord> records = dataList.map((item) {
            return AttendanceRecord(
              date: formatDate(item['date']), // Format as DD-MMM-YYYY
              shift: item['shift'] ?? '--',
              inTime: item['in']?.isEmpty == true ? '--' : item['in'] ?? '--',
              outTime: item['out']?.isEmpty == true ? '--' : item['out'] ?? '--',
              totalHours: formatDuration(item['total_hours'] ?? {}),
              lateHours: formatDuration(item['late'] ?? {}),
              earlyOut: formatDuration(item['early_out'] ?? {}),
              extraHours: formatDuration(item['extra_time'] ?? {}),
              day: getFullDayName(item['day_name']), // Full day name
              status: item['status'] ?? '--',
            );
          }).toList();
          
          // Parse leave balance and leave avail
          final parsedLeaveBalance = responseData['leave_balance'];
          final parsedLeaveAvail = responseData['leave_avail'];
          
          debugPrint('📊 Leave Balance: $parsedLeaveBalance');
          debugPrint('📊 Leave Avail: $parsedLeaveAvail');
          
          setState(() {
            attendanceData = records;
            leaveBalance = parsedLeaveBalance;
            leaveAvail = parsedLeaveAvail;
          });

          // Re-measure top section height after leave balance loads
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _topSectionKey.currentContext;
            if (ctx != null) {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box != null) setState(() => _topSectionHeight = box.size.height);
            }
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded ${records.length} attendance records'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No attendance data found'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load data: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Network error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Function to show Apply Leave dialog
  void _showApplyLeaveDialog(String date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Apply Leave for $date'),
          content: const Text('Do you want to apply for leave on this date?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLeaveApplication(date);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Apply Leave',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Function to navigate to leave application page
  void _navigateToLeaveApplication(String date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeaveApplicationPage(
          autoOpenAddForm: true,
        ),
      ),
    ).then((_) {
      // Optionally refresh attendance data when returning from leave application
      _fetchAttendanceData();
    });
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4CAF50), // Green
                Color(0xFF2196F3), // Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daily Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Main scrollable content ──────────────────────────────────
          SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leave balance + filters — scrolls away with the page
                Container(
                  key: _topSectionKey,
                  padding: const EdgeInsets.all(16),
                  color: theme.cardColor,
                  child: Column(
                    children: [
                      if (leaveBalance != null)
                        _buildLeaveBalanceSection()
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                          child: const Text(
                            'Leave Balance unavailable',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              'Year',
                              selectedYear,
                              yearList,
                              (value) => setState(() => selectedYear = value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              'Month',
                              selectedMonth,
                              monthList,
                              (value) {
                                setState(() => selectedMonth = value!);
                              },
                              displayValue: getMonthName(selectedMonth),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _fetchAttendanceData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Search',
                                      style: TextStyle(color: Colors.white),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Table: date column fixed left, rest horizontally scrollable
                _buildTableSection(),
                const SizedBox(height: 34),
              ],
            ),
          ),

          // ── Sticky table header overlay ──────────────────────────────
          // Always in tree (so controller stays attached), visibility toggled
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Visibility(
              visible: _isHeaderSticky,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: false,
              child: IgnorePointer(
                child: _buildStickyHeaderOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Column width constants ─────────────────────────────────────────────
  static const double _dateColW      = 100.0; // full date: "01-Dec-2025"
  static const double _dateColWSmall =  44.0; // day only: "01"
  static const double _divW         = 1.0;

  // Current date column width — shrinks when scrolled horizontally
  double get _currentDateColW {
    final scrolled = _horizontalScrollController.hasClients &&
        _horizontalScrollController.positions.length == 1 &&
        _horizontalScrollController.offset > 4;
    return scrolled ? _dateColWSmall : _dateColW;
  }
  static const double _shiftColW    = 70.0;
  static const double _inColW       = 60.0;
  static const double _outColW      = 60.0;
  static const double _totalHrsW    = 130.0;
  static const double _lateHrsW     = 130.0;
  static const double _earlyOutW    = 130.0;
  static const double _extraHrsW    = 130.0;
  static const double _dayColW      = 90.0;
  static const double _statusColW   = 90.0;
  static const double _actionColW   = 100.0;
  static const double _rowH         = 44.0;
  static const double _headerH      = 44.0;


  // ── Inline table header (scrolls with page) ──────────────────────────
  Widget _buildTableHeader() {
    return _buildTableSection(headerOnly: true);
  }

  // ── Full table: fixed date col + horizontally scrollable content ──────
  Widget _buildTableSection({bool headerOnly = false}) {
    // Build all rows (header + data + total)
    final rows = <_TableRowData>[];

    // Header row
    rows.add(_TableRowData(isHeader: true));

    if (!headerOnly) {
      for (final record in attendanceData) {
        rows.add(_TableRowData(record: record));
      }
      if (attendanceData.isNotEmpty) {
        rows.add(_TableRowData(isTotalRow: true));
      }
    }

    return Stack(
      children: [
        // ── Scrollable part (all columns including date) ─────────────
        SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows.map((row) => _buildFullRow(row)).toList(),
          ),
        ),

        // ── Fixed date column overlay ────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows.map((row) => _buildFixedDateCell(row)).toList(),
        ),
      ],
    );
  }

  Widget _buildFullRow(_TableRowData row) {
    if (row.isHeader) {
      return Container(
        height: _headerH,
        decoration: BoxDecoration(color: Colors.grey[100]),
        child: Row(
          children: [
            SizedBox(width: _currentDateColW), // placeholder for fixed date col
            _vDivider(height: _headerH),
            _headerCell('Shift',       _shiftColW),
            _vDivider(height: _headerH),
            _headerCell('In',          _inColW),
            _vDivider(height: _headerH),
            _headerCell('Out',         _outColW),
            _vDivider(height: _headerH),
            _headerCell('Total Hours', _totalHrsW),
            _vDivider(height: _headerH),
            _headerCell('Late Hours',  _lateHrsW),
            _vDivider(height: _headerH),
            _headerCell('Early Out',   _earlyOutW),
            _vDivider(height: _headerH),
            _headerCell('Extra Hours', _extraHrsW),
            _vDivider(height: _headerH),
            _headerCell('Day',         _dayColW),
            _vDivider(height: _headerH),
            _headerCell('Status',      _statusColW),
            _vDivider(height: _headerH),
            _headerCell('',            _actionColW),
          ],
        ),
      );
    }

    if (row.isTotalRow) {
      final totals = _computeTotals();
      return Container(
        height: _rowH,
        color: Colors.grey[200],
        child: Row(
          children: [
            SizedBox(width: _currentDateColW), // placeholder
            _vDivider(height: _rowH),
            SizedBox(width: _shiftColW + _divW + _inColW + _divW + _outColW),
            _vDivider(height: _rowH),
            _totalCell(_formatTotalMinutes(totals['totalHours']!), _totalHrsW),
            _vDivider(height: _rowH),
            _totalCell(_formatTotalMinutes(totals['lateHours']!),  _lateHrsW),
            _vDivider(height: _rowH),
            _totalCell(_formatTotalMinutes(totals['earlyOut']!),   _earlyOutW),
            _vDivider(height: _rowH),
            _totalCell(_formatTotalMinutes(totals['extraHours']!), _extraHrsW),
            _vDivider(height: _rowH),
            SizedBox(width: _dayColW),
            _vDivider(height: _rowH),
            SizedBox(width: _statusColW),
            _vDivider(height: _rowH),
            SizedBox(width: _actionColW),
          ],
        ),
      );
    }

    final record = row.record!;
    final statusInfo = getStatusInfo(record.status);
    return Container(
      height: _rowH,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          SizedBox(width: _currentDateColW), // placeholder for fixed date col
          _vDivider(height: _rowH),
          _dataCell(record.shift,      _shiftColW),
          _vDivider(height: _rowH),
          _dataCell(record.inTime,     _inColW),
          _vDivider(height: _rowH),
          _dataCell(record.outTime,    _outColW),
          _vDivider(height: _rowH),
          _dataCell(record.totalHours, _totalHrsW),
          _vDivider(height: _rowH),
          _dataCell(record.lateHours,  _lateHrsW),
          _vDivider(height: _rowH),
          _dataCell(record.earlyOut,   _earlyOutW),
          _vDivider(height: _rowH),
          _dataCell(record.extraHours, _extraHrsW),
          _vDivider(height: _rowH),
          _dataCell(record.day,        _dayColW),
          _vDivider(height: _rowH),
          SizedBox(
            width: _statusColW,
            height: _rowH,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: statusInfo['color'],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusInfo['text'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          _vDivider(height: _rowH),
          SizedBox(
            width: _actionColW,
            height: _rowH,
            child: Center(
              child: (record.status == 'A' || record.status == 'MS')
                  ? ElevatedButton(
                      onPressed: () => _showApplyLeaveDialog(record.date),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: const Size(80, 28),
                      ),
                      child: const Text(
                        'Apply Leave',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedDateCell(_TableRowData row) {
    final scrolled = _horizontalScrollController.hasClients &&
        _horizontalScrollController.positions.length == 1 &&
        _horizontalScrollController.offset > 4;

    if (row.isHeader) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _currentDateColW,
        height: _headerH,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border(right: BorderSide(color: Colors.grey[300]!)),
        ),
        alignment: Alignment.centerLeft,
        child: const Text('Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );
    }

    if (row.isTotalRow) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _currentDateColW,
        height: _rowH,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border(right: BorderSide(color: Colors.grey[400]!)),
        ),
        alignment: Alignment.centerLeft,
        child: const Text('Total',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
    }

    final record = row.record!;
    final dateDisplay = scrolled
        ? record.date.split('-').first
        : record.date;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _currentDateColW,
      height: _rowH,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          dateDisplay,
          key: ValueKey(dateDisplay),
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }

  // ── Sticky overlay header (synced via _stickyHScrollController) ────────
  Widget _buildStickyHeaderOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fixed date cell
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _currentDateColW,
            height: _headerH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            alignment: Alignment.centerLeft,
            child: const Text('Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          // Scrollable header columns — driven by _stickyHScrollController
          Expanded(
            child: SingleChildScrollView(
              controller: _stickyHScrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  _vDivider(height: _headerH),
                  _headerCell('Shift',       _shiftColW),
                  _vDivider(height: _headerH),
                  _headerCell('In',          _inColW),
                  _vDivider(height: _headerH),
                  _headerCell('Out',         _outColW),
                  _vDivider(height: _headerH),
                  _headerCell('Total Hours', _totalHrsW),
                  _vDivider(height: _headerH),
                  _headerCell('Late Hours',  _lateHrsW),
                  _vDivider(height: _headerH),
                  _headerCell('Early Out',   _earlyOutW),
                  _vDivider(height: _headerH),
                  _headerCell('Extra Hours', _extraHrsW),
                  _vDivider(height: _headerH),
                  _headerCell('Day',         _dayColW),
                  _vDivider(height: _headerH),
                  _headerCell('Status',      _statusColW),
                  _vDivider(height: _headerH),
                  _headerCell('',            _actionColW),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Small helper widgets ───────────────────────────────────────────────

  Widget _headerCell(String text, double width, {bool isFixed = false}) {
    return SizedBox(
      width: width,
      height: _headerH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String text, double width) {
    return SizedBox(
      width: width,
      height: _rowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _totalCell(String text, double width) {
    return SizedBox(
      width: width,
      height: _rowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _vDivider({required double height}) {
    return Container(width: _divW, height: height, color: Colors.grey[300]);
  }

  Widget _buildLeaveBalanceSection() {
    final items = [
      _LeaveBalanceItem(
        code: 'EL',
        label: 'Earned Leave',
        value: leaveBalance!['bel']?.toStringAsFixed(1) ?? '0.0',
        accentColor: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFF90CAF9),
      ),
      _LeaveBalanceItem(
        code: 'CL',
        label: 'Casual Leave',
        value: leaveBalance!['bcl']?.toStringAsFixed(1) ?? '0.0',
        accentColor: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
      ),
      _LeaveBalanceItem(
        code: 'SL',
        label: 'Sick Leave',
        value: leaveBalance!['bsl']?.toStringAsFixed(1) ?? '0.0',
        accentColor: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
      ),
      _LeaveBalanceItem(
        code: 'ML',
        label: 'Medical Leave',
        value: leaveBalance!['bml']?.toStringAsFixed(1) ?? '0.0',
        accentColor: const Color(0xFF6A1B9A),
        bgColor: const Color(0xFFF3E5F5),
        borderColor: const Color(0xFFCE93D8),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Leave Balance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF37474F),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Cards row
        Row(
          children: items.map((item) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item.code != 'ML' ? 6 : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: item.borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Leave code badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.code,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Balance value
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: item.accentColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Leave full name
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: item.accentColor.withValues(alpha: 0.75),
                          letterSpacing: 0.2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? displayValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    label == 'Month' ? getMonthName(item) : item,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// Helper to describe a table row type
class _TableRowData {
  final bool isHeader;
  final bool isTotalRow;
  final AttendanceRecord? record;

  const _TableRowData({
    this.isHeader = false,
    this.isTotalRow = false,
    this.record,
  });
}

class AttendanceRecord {
  final String date;
  final String shift;
  final String inTime;
  final String outTime;
  final String totalHours;
  final String lateHours;
  final String earlyOut;
  final String extraHours;
  final String day;
  final String status;

  AttendanceRecord({
    required this.date,
    required this.shift,
    required this.inTime,
    required this.outTime,
    required this.totalHours,
    required this.lateHours,
    required this.earlyOut,
    required this.extraHours,
    required this.day,
    required this.status,
  });
}

class _LeaveBalanceItem {
  final String code;
  final String label;
  final String value;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _LeaveBalanceItem({
    required this.code,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });
}
