import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'clocking.dart';
import 'login.dart';
import 'daily_attendance.dart';
import 'application_approval.dart';
import 'miss_punch.dart';
import 'leave_application.dart';
import 'on_duty.dart';
import 'comp_off.dart';
import 'pay_slip.dart';
import 'team_attendance.dart';
import 'employee.dart';
import 'wfh.dart';
import 'settings.dart';
import 'attendance_calendar.dart';
import 'my_profile.dart';
import 'policy_procedure.dart';
import 'travel_claim.dart';
import 'general_expense.dart';
import 'conveyance_claim.dart';
import 'reimbursement.dart';
import 'claim_approval.dart';
import '../utils/app_localizations.dart';
import '../utils/location_service.dart';
import '../utils/auth_service.dart';
import '../utils/ntfy_listener.dart';
import '../utils/ntfy_background_service.dart';
import '../utils/permission_service.dart';
import '../utils/dummy_data_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final PermissionService _permissionService = PermissionService();
  
  Timer? _timer;
  DateTime currentTime = DateTime.now();
  String currentLocation = "Fetching location...";
  bool isLocationLoading = true;
  
  // Last clocking data
  DateTime? lastClockingTime;
  String? lastClockingLocation;
  String? lastClockingType;
  bool hasLastClocking = false;
  
  // Login session data
  int? daysUntilLoginExpiry;
  
  // User data
  String userName = '';
  
  // Attendance data
  String workingDays = '0';
  String absentDays = '0';
  String holidays = '0';
  String weekOffs = '0';
  String onDutyCount = '0';
  bool isLoadingAttendance = false;
  bool _isRefreshing = false;
  String _lastRefreshedText = '';

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    try {
      // Fire location + clocking in background (non-critical)
      _getCurrentLocation();
      _loadLastClockingData();
      // Await the data calls so spinner stays until fresh data is shown
      await Future.wait([
        _fetchAttendanceDataFromAPI(),
        _fetchDailyAttendanceData(),
      ]);
      final now = TimeOfDay.now();
      setState(() {
        _lastRefreshedText =
            'Updated at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      });
      HapticFeedback.lightImpact();
    } catch (_) {
    } finally {
      setState(() => _isRefreshing = false);
    }
  }
  
  // Daily attendance data for calendar (date -> status mapping)
  Map<String, String> dailyAttendanceData = {};
  
  // Leave data
  String totalLeave = '0';
  String elUsed = '0';
  String slUsed = '0';
  String clUsed = '0';
  
  // Leave balance data
  String totalEl = '0';
  String totalCl = '0';
  String totalSl = '0';
  String balEl = '0';
  String balCl = '0';
  String balSl = '0';
  
  // ESS menu expansion state
  bool isESSExpanded = false;
  
  // Visitors menu expansion state
  bool isVisitorsExpanded = false;
  
  // Claim & Reimbursement menu expansion state
  bool isClaimExpanded = false;
  
  // Permissions cache
  final Map<String, bool> _permissionsCache = {};
  
  // Menu items cache to prevent rebuilding
  List<Widget>? _essMenuItems;
  List<Widget>? _visitorsMenuItems;
  List<Widget>? _claimMenuItems;
  bool _menuItemsLoaded = false;
  bool _hasPunchingPermission = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _getCurrentLocation();
    _loadLastClockingData();
    _loadAttendanceData();
    _loadUserData();
    _checkLoginExpiry();
    _startMidnightResetTimer(); // Add midnight reset functionality
    _startNtfyListener(); // Start ntfy listener when home page loads
    _loadPermissions(); // Load permissions on init
  }
  
  /// Load and cache permissions
  Future<void> _loadPermissions() async {
    try {
      debugPrint('🔐 Loading user permissions...');
      await _permissionService.printAllPermissions();
      
      // Clear old cache first
      _essMenuItems = null;
      _visitorsMenuItems = null;
      _claimMenuItems = null;
      _menuItemsLoaded = false;
      _hasPunchingPermission = false;
      
      // Pre-load menu items
      _essMenuItems = await _buildESSSubItems();
      _visitorsMenuItems = await _buildVisitorsSubItems();
      _claimMenuItems = await _buildClaimSubItems();
      _hasPunchingPermission = await _permissionService.hasAnyPermission('Punching');
      _menuItemsLoaded = true;
      
      debugPrint('✅ Menu items cached: ESS=${_essMenuItems?.length ?? 0}, Visitors=${_visitorsMenuItems?.length ?? 0}, Claim=${_claimMenuItems?.length ?? 0}');
      
      // Trigger rebuild to show menu items
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error loading permissions: $e');
    }
  }
  
  /// Refresh permissions and menu items (useful if permissions change without re-login)
  Future<void> _refreshPermissions() async {
    debugPrint('🔄 Refreshing permissions and menu cache...');
    _permissionsCache.clear();
    await _loadPermissions();
  }
  
  /// Check if user has read permission for a page
  Future<bool> _hasReadPermission(String pageName) async {
    final cacheKey = '${pageName}_read';
    if (_permissionsCache.containsKey(cacheKey)) {
      return _permissionsCache[cacheKey]!;
    }
    
    final hasPermission = await _permissionService.canRead(pageName);
    _permissionsCache[cacheKey] = hasPermission;
    return hasPermission;
  }

  @override
  void dispose() {
    _timer?.cancel();
    NtfyListener.stop(); // Stop ntfy listener when HomePage is disposed
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final newTime = DateTime.now();
        // Only update if the time has actually changed (avoid unnecessary rebuilds)
        if (newTime.second != currentTime.second) {
          setState(() {
            currentTime = newTime;
          });
        }
      }
    });
  }

  void _getCurrentLocation() async {
    try {
      setState(() {
        isLocationLoading = true;
        currentLocation = "Fetching location...";
      });

      final locationData = await LocationService.getCurrentLocationData();
      
      if (mounted) {
        setState(() {
          currentLocation = locationData['address'] ?? 'Unable to get location';
          isLocationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentLocation = 'Error getting location: ${e.toString()}';
          isLocationLoading = false;
        });
      }
    }
  }

  void _loadLastClockingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First check for punch data from API (takes priority)
      final punchInDataStr = prefs.getString('punch_in_data');
      final punchOutDataStr = prefs.getString('punch_out_data');
      
      bool foundApiPunchData = false;
      
      // Check punch out data first (most recent)
      if (punchOutDataStr != null && punchOutDataStr.isNotEmpty) {
        try {
          final punchOutData = jsonDecode(punchOutDataStr) as Map<String, dynamic>;
          if (punchOutData.containsKey('punch_time')) {
            final punchTimeStr = punchOutData['punch_time']?.toString();
            final punchLoc = punchOutData['punch_loc']?.toString() ?? 'Location not available';
            
            if (punchTimeStr != null) {
              final punchDateTime = _parseApiDateTime(punchTimeStr);
              final currentDateTime = DateTime.now();
              
              // Check if punch out is from today
              if (_isSameDay(punchDateTime, currentDateTime)) {
                setState(() {
                  lastClockingTime = punchDateTime;
                  lastClockingLocation = punchLoc;
                  lastClockingType = 'CLOCKED-OUT';
                  hasLastClocking = true;
                });
                foundApiPunchData = true;
                debugPrint('📱 Loaded punch out data from API');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing punch out data: $e');
        }
      }
      
      // If no punch out data, check punch in data
      if (!foundApiPunchData && punchInDataStr != null && punchInDataStr.isNotEmpty) {
        try {
          final punchInData = jsonDecode(punchInDataStr) as Map<String, dynamic>;
          if (punchInData.containsKey('punch_time')) {
            final punchTimeStr = punchInData['punch_time']?.toString();
            final punchLoc = punchInData['punch_loc']?.toString() ?? 'Location not available';
            
            if (punchTimeStr != null) {
              final punchDateTime = _parseApiDateTime(punchTimeStr);
              final currentDateTime = DateTime.now();
              
              // Check if punch in is from today
              if (_isSameDay(punchDateTime, currentDateTime)) {
                setState(() {
                  lastClockingTime = punchDateTime;
                  lastClockingLocation = punchLoc;
                  lastClockingType = 'CLOCKED-IN';
                  hasLastClocking = true;
                });
                foundApiPunchData = true;
                debugPrint('📱 Loaded punch in data from API');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error parsing punch in data: $e');
        }
      }
      
      // If no API punch data found, fall back to local data
      if (!foundApiPunchData) {
        final lastClockingTimeStr = prefs.getString('last_clocking_time');
        final lastLocation = prefs.getString('last_clocking_location');
        final lastType = prefs.getString('last_clocking_type');
        
        if (lastClockingTimeStr != null) {
          final lastClockingDateTime = DateTime.parse(lastClockingTimeStr);
          final currentDateTime = DateTime.now();
          
          // Check if last clocking is from today
          if (_isSameDay(lastClockingDateTime, currentDateTime)) {
            setState(() {
              lastClockingTime = lastClockingDateTime;
              lastClockingLocation = lastLocation ?? 'Location not available';
              lastClockingType = lastType ?? 'CLOCKED-IN';
              hasLastClocking = true;
            });
            debugPrint('📱 Loaded local clocking data');
          } else {
            // Last clocking is from previous day, clear it
            debugPrint('🗓️ Last clocking is from previous day, clearing data for new day');
            setState(() {
              hasLastClocking = false;
              lastClockingTime = null;
              lastClockingLocation = null;
              lastClockingType = null;
            });
          }
        } else {
          setState(() {
            hasLastClocking = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading last clocking data: $e');
      setState(() {
        hasLastClocking = false;
      });
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Parse API datetime string that comes in IST format (e.g., "2025-12-29T13:32:09+05:30")
  /// and convert it to local DateTime
  DateTime _parseApiDateTime(String dateTimeStr) {
    try {
      // Parse the datetime string with timezone info
      final parsedDateTime = DateTime.parse(dateTimeStr);
      
      // If the parsed datetime is in UTC, convert to local
      if (parsedDateTime.isUtc) {
        return parsedDateTime.toLocal();
      }
      
      // If it has timezone offset, DateTime.parse handles it correctly
      return parsedDateTime;
    } catch (e) {
      debugPrint('❌ Error parsing datetime: $dateTimeStr, error: $e');
      // Fallback to current time if parsing fails
      return DateTime.now();
    }
  }

  void _loadAttendanceData() async {
    setState(() {
      isLoadingAttendance = true;
    });
    
    try {
      // First try to fetch from API
      await _fetchAttendanceDataFromAPI();
      // Also fetch daily attendance data for calendar
      await _fetchDailyAttendanceData();
    } catch (e) {
      debugPrint('❌ Error loading attendance data: $e');
      
      // Check if this is test user - if yes, don't show error
      final isTest = await DummyDataService.isTestUser();
      if (!isTest) {
        // Set all values to 0 when API fails for real users
        setState(() {
          workingDays = '0';
          absentDays = '0';
          holidays = '0';
          weekOffs = '0';
          onDutyCount = '0';
          totalLeave = '0';
          elUsed = '0';
          slUsed = '0';
          clUsed = '0';
          totalEl = '0';
          totalCl = '0';
          totalSl = '0';
          balEl = '0';
          balCl = '0';
          balSl = '0';
        });
        
        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load attendance data from server'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      setState(() {
        isLoadingAttendance = false;
      });
    }
  }

  Future<void> _fetchAttendanceDataFromAPI() async {
    try {
      debugPrint('🔗 Starting attendance API call...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - loading dummy attendance data');
        
        // Load dummy data from SharedPreferences (already set during login)
        final prefs = await SharedPreferences.getInstance();
        
        String? dummyWorkingDays = prefs.getString('attendance_working_days');
        String? dummyAbsentDays = prefs.getString('attendance_absent_days');
        String? dummyHolidays = prefs.getString('attendance_holidays');
        String? dummyWeekOffs = prefs.getString('attendance_week_offs');
        
        // If data is not initialized or is 0, re-initialize dummy data
        if (dummyWorkingDays == null || dummyWorkingDays == '0' || dummyWorkingDays.isEmpty) {
          debugPrint('⚠️ Dummy data not found in SharedPreferences - re-initializing...');
          await DummyDataService.initializeDummyData();
          
          // Reload after initialization
          dummyWorkingDays = prefs.getString('attendance_working_days') ?? '18';
          dummyAbsentDays = prefs.getString('attendance_absent_days') ?? '2';
          dummyHolidays = prefs.getString('attendance_holidays') ?? '3';
          dummyWeekOffs = prefs.getString('attendance_week_offs') ?? '8';
        }
        
        final dummyTotalLeave = prefs.getString('leave_total') ?? '8';
        final dummyElUsed = prefs.getString('leave_el_used') ?? '5';
        final dummySlUsed = prefs.getString('leave_sl_used') ?? '2';
        final dummyClUsed = prefs.getString('leave_cl_used') ?? '1';
        
        debugPrint('📊 Loaded dummy data from SharedPreferences:');
        debugPrint('   Working Days: $dummyWorkingDays');
        debugPrint('   Absent Days: $dummyAbsentDays');
        debugPrint('   Holidays: $dummyHolidays');
        debugPrint('   Week Offs: $dummyWeekOffs');
        debugPrint('   Total Leave: $dummyTotalLeave');
        
        setState(() {
          workingDays = dummyWorkingDays!;
          absentDays = dummyAbsentDays!;
          holidays = dummyHolidays!;
          weekOffs = dummyWeekOffs!;
          totalLeave = dummyTotalLeave;
          elUsed = dummyElUsed;
          slUsed = dummySlUsed;
          clUsed = dummyClUsed;
          isLoadingAttendance = false;
        });
        
        debugPrint('✅ Dummy attendance data loaded successfully');
        debugPrint('📊 UI State updated - workingDays: $workingDays, absentDays: $absentDays');
        return;
      }
      
      // Get employee paycode
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        debugPrint('❌ No employee paycode found');
        throw Exception('Employee ID not found. Please login again.');
      }
      
      debugPrint('📱 Employee paycode: $empPaycode');

      // Get current year and month
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      
      // Build query parameters
      final queryParams = {
        'emp_paycode': empPaycode,
        'year': currentYear.toString(),
        'month': currentMonth.toString(),
      };
      
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final endpoint = '/checkin_checkout/?$queryString';
      
      debugPrint('🔗 Fetching attendance data from: $endpoint');
      debugPrint('📋 Parameters: emp_paycode=$empPaycode, year=$currentYear, month=$currentMonth');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 API Response status: ${response.statusCode}');
      debugPrint('📄 API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Attendance data fetched successfully');
        debugPrint('📋 Response data structure: ${responseData.keys}');
        
        // Parse the response based on the new format
        if (responseData['status'] == 'Success') {

          // Parse attendance counts — data may be empty (e.g. start of month)
          String apiWorkingDays = '0';
          String apiAbsentDays = '0';
          String apiHolidays = '0';
          String apiWeekOffs = '0';
          String apiLeaveCount = '0';
          String apiOdCount = '0';

          if (responseData['data'] != null &&
              responseData['data'] is List &&
              (responseData['data'] as List).isNotEmpty) {
            final attendanceData = responseData['data'][0];
            debugPrint('📝 Processing attendance item: $attendanceData');
            apiWorkingDays = attendanceData['working_day']?.toString() ?? '0';
            apiAbsentDays  = attendanceData['absent_count']?.toString() ?? '0';
            apiHolidays    = attendanceData['holiday_count']?.toString() ?? '0';
            apiWeekOffs    = attendanceData['sunday_count']?.toString() ?? '0';
            apiLeaveCount  = attendanceData['leave_count']?.toString() ?? '0';
            apiOdCount     = attendanceData['od_count']?.toString() ?? '0';
          } else {
            debugPrint('ℹ️ No attendance records for this period (data is empty) — showing zeros');
          }

          // Parse leave balance data if available (present even when data is empty)
          if (responseData['leaves'] != null && responseData['leaves'] is List) {
            final leavesList = responseData['leaves'] as List;
            
            // Extract total leaves (index 0)
            if (leavesList.isNotEmpty && leavesList[0] is Map) {
              final totalLeaves = leavesList[0];
              final apiTotalEl = totalLeaves['total_el']?.toString() ?? '0';
              final apiTotalCl = totalLeaves['total_cl']?.toString() ?? '0';
              final apiTotalSl = totalLeaves['total_sl']?.toString() ?? '0';
              
              debugPrint('📊 Total Leaves - EL: $apiTotalEl, CL: $apiTotalCl, SL: $apiTotalSl');
              
              setState(() {
                totalEl = apiTotalEl;
                totalCl = apiTotalCl;
                totalSl = apiTotalSl;
              });
            }
            
            // Extract used leaves (index 1)
            if (leavesList.length > 1 && leavesList[1] is Map) {
              final usedLeaves = leavesList[1];
              final apiElUsed = usedLeaves['el_used']?.toString() ?? '0';
              final apiClUsed = usedLeaves['cl_used']?.toString() ?? '0';
              final apiSlUsed = usedLeaves['sl_used']?.toString() ?? '0';
              
              debugPrint('📊 Used Leaves - EL: $apiElUsed, CL: $apiClUsed, SL: $apiSlUsed');
              
              setState(() {
                elUsed = apiElUsed;
                clUsed = apiClUsed;
                slUsed = apiSlUsed;
              });
            }
            
            // Extract balance leaves (index 2)
            if (leavesList.length > 2 && leavesList[2] is Map) {
              final balanceLeaves = leavesList[2];
              final apiBalEl = balanceLeaves['bal_el']?.toString() ?? '0';
              final apiBalCl = balanceLeaves['bal_cl']?.toString() ?? '0';
              final apiBalSl = balanceLeaves['bal_sl']?.toString() ?? '0';
              
              debugPrint('📊 Balance Leaves (checkin_checkout) - EL: $apiBalEl, CL: $apiBalCl, SL: $apiBalSl (will be overwritten by daily-attendance API)');
              // Note: balEl/balCl/balSl are set by _fetchDailyAttendanceData which is more accurate
            }
          }
          
          setState(() {
            workingDays = apiWorkingDays;
            absentDays = apiAbsentDays;
            holidays = apiHolidays;
            weekOffs = apiWeekOffs;
            onDutyCount = apiOdCount;
            totalLeave = apiLeaveCount;
          });
          
          debugPrint('📊 API attendance data loaded:');
          debugPrint('   Working Days: $workingDays');
          debugPrint('   Absent Days: $absentDays');
          debugPrint('   Holidays: $holidays');
          debugPrint('   Week Offs: $weekOffs');
          debugPrint('   Leave Count: $totalLeave');
          debugPrint('   OD Count: $apiOdCount');
          
        } else {
          debugPrint('⚠️ Attendance API returned non-Success status: ${responseData['status']}');
          throw Exception('Attendance API error: ${responseData['status']}');
        }
      } else {
        debugPrint('❌ Attendance API error: Status ${response.statusCode}');
        debugPrint('📄 Error response: ${response.body}');
        throw Exception('Attendance API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching attendance data from API: $e');
      rethrow;
    }
  }

  Future<void> _fetchDailyAttendanceData() async {
    try {
      debugPrint('🔗 Starting daily attendance API call for calendar...');
      
      // Check if this is the test user - skip API call for test users
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - skipping daily attendance API call');
        return;
      }
      
      // Get employee paycode
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        debugPrint('❌ No employee paycode found for daily attendance');
        return;
      }
      
      // Get current year and month
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      
      final endpoint = '/ess/daily-attendance/?json=1&emp_paycode=$empPaycode&year=$currentYear&month=$currentMonth';
      debugPrint('🔗 Fetching daily attendance from: $endpoint');
      
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Daily attendance response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Daily attendance data fetched successfully');
        debugPrint('📋 Full response keys: ${responseData.keys.toList()}');
        
        // Parse leave balance directly from API (bel, bcl, bsl, bml)
        if (responseData['leave_balance'] != null) {
          final leaveBalance = responseData['leave_balance'];
          debugPrint('📊 Raw leave_balance data: $leaveBalance');

          final balanceEl = leaveBalance['bel']?.toString() ?? '0.0';
          final balanceCl = leaveBalance['bcl']?.toString() ?? '0.0';
          final balanceSl = leaveBalance['bsl']?.toString() ?? '0.0';
          final balanceMl = leaveBalance['bml']?.toString() ?? '0.0';

          debugPrint('📊 Leave Balance: EL=$balanceEl, CL=$balanceCl, SL=$balanceSl, ML=$balanceMl');

          setState(() {
            balEl = balanceEl;
            balCl = balanceCl;
            balSl = balanceSl;
          });
        } else {
          debugPrint('⚠️ No leave_balance found in response');
        }

        // Parse leave avail (used leaves) from daily attendance API
        if (responseData['leave_avail'] != null) {
          final leaveAvail = responseData['leave_avail'];
          debugPrint('📊 Raw leave_avail data: $leaveAvail');

          final usedEl = leaveAvail['used_el']?.toString() ?? '0.0';
          final usedCl = leaveAvail['used_cl']?.toString() ?? '0.0';
          final usedSl = leaveAvail['used_sl']?.toString() ?? '0.0';

          debugPrint('📊 Leave Used: EL=$usedEl, CL=$usedCl, SL=$usedSl');

          setState(() {
            elUsed = usedEl;
            clUsed = usedCl;
            slUsed = usedSl;
          });
        } else {
          debugPrint('⚠️ No leave_avail found in response');
        }
        
        // Parse daily attendance data for calendar
        if (responseData['data'] != null) {
          final List<dynamic> dataList = responseData['data'];
          final Map<String, String> attendanceMap = {};
          
          for (var item in dataList) {
            final date = item['date']?.toString();
            final status = item['status']?.toString();
            
            if (date != null && status != null) {
              attendanceMap[date] = status;
            }
          }
          
          setState(() {
            dailyAttendanceData = attendanceMap;
          });
          
          debugPrint('📅 Loaded ${attendanceMap.length} days of attendance data for calendar');
        }
      } else {
        debugPrint('❌ Daily attendance API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching daily attendance data: $e');
    }
  }

  void _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        userName = prefs.getString('user_name') ?? '';
      });
      
      debugPrint('👤 Loaded user data:');
      debugPrint('   User Name: $userName');
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  void _startNtfyListener() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try to get emp_paycode first (saved during login)
      String? empPaycode = prefs.getString('emp_paycode');
      
      // If emp_paycode not found, try to get username as fallback
      if (empPaycode == null || empPaycode.isEmpty) {
        empPaycode = prefs.getString('username');
      }
      
      // If still not found, try user_email (which stores the username)
      if (empPaycode == null || empPaycode.isEmpty) {
        empPaycode = prefs.getString('user_email');
      }
      
      if (empPaycode != null && empPaycode.isNotEmpty) {
        debugPrint('🔔 Starting ntfy services with emp_paycode: $empPaycode');
        
        // Start both services - background first, foreground as backup
        final backgroundStarted = await NtfyBackgroundService.start();
        if (backgroundStarted) {
          debugPrint('✅ Background ntfy service started - will run even when app is closed');
        } else {
          debugPrint('⚠️ Failed to start background service, falling back to foreground only');
        }
        
        // Always start foreground listener as backup/primary service
        debugPrint('🔔 Starting foreground ntfy listener as backup');
        NtfyListener.start(empPaycode);
      } else {
        debugPrint('⚠️ No emp_paycode or username found to start ntfy listener');
      }
    } catch (e) {
      debugPrint('❌ Error starting ntfy listener: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('login_time');
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      // NOTE: autofill_username and autofill_password are intentionally NOT removed
      // so the login screen can pre-fill credentials after logout
      
      // Clear permissions
      await _permissionService.clearPermissions();
      
      // Stop both ntfy services on logout
      NtfyListener.stop();
      await NtfyBackgroundService.stop();
      debugPrint('🔕 Stopped all ntfy services on logout');
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error during logout. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _checkLoginExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginTimeStr = prefs.getString('login_time');
      
      if (loginTimeStr != null) {
        final loginTime = DateTime.parse(loginTimeStr);
        final currentTime = DateTime.now();
        final daysPassed = currentTime.difference(loginTime).inDays;
        final daysRemaining = 30 - daysPassed;
        
        setState(() {
          daysUntilLoginExpiry = daysRemaining > 0 ? daysRemaining : 0;
        });
      }
    } catch (e) {
      debugPrint('Error checking login expiry: $e');
    }
  }

  void _startMidnightResetTimer() {
    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = nextMidnight.difference(now);
    
    debugPrint('🕛 Setting up midnight reset timer. Next reset in: ${timeUntilMidnight.inHours}h ${timeUntilMidnight.inMinutes.remainder(60)}m');
    
    // Set timer for midnight reset
    Timer(timeUntilMidnight, () {
      _performMidnightReset();
      // Start daily timer for subsequent days
      Timer.periodic(const Duration(days: 1), (timer) {
        if (mounted) {
          _performMidnightReset();
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _performMidnightReset() async {
    try {
      debugPrint('🌙 Performing midnight reset - refreshing clocking data for new day');
      
      // Refresh last clocking data to check if it's from previous day
      _loadLastClockingData();
      
      // Refresh attendance data
      _loadAttendanceData();
      
      // Show notification that data has been refreshed for new day
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Data refreshed for new day - Ready to clock in!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      debugPrint('✅ Midnight reset completed successfully');
    } catch (e) {
      debugPrint('❌ Error during midnight reset: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 12),
              Text('Sign Out'),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out? You will need to login again to access the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildDrawer(),
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)?.dashboard ?? 'Dashboard',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _getCurrentLocation();
              _loadAttendanceData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing data...')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: Colors.white,
        backgroundColor: const Color(0xFF1E88E5),
        strokeWidth: 2.5,
        displacement: 60,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // "Last updated" banner — fades in after refresh
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: _lastRefreshedText.isNotEmpty ? 32 : 0,
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    child: _lastRefreshedText.isNotEmpty
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 14, color: Color(0xFF1E88E5)),
                              const SizedBox(width: 6),
                              Text(
                                _lastRefreshedText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E88E5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Profile Section
                  Container(
              width: double.infinity,
              color: isDark ? theme.cardColor : Colors.grey[200],
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,                            
                          size: 40,
                          color:Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (userName.isNotEmpty) ...[
                              Text(
                                userName,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            GestureDetector(
                              onTap: () {
                                // Navigate to My Profile page
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MyProfilePage(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)?.profile ??
                                          'MY PROFILE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.search,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.access_time,
                            color: theme.textTheme.bodySmall?.color, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'My Attendance - ',
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 14,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Since ${DateFormat('MMMM yyyy').format(currentTime)}',
                                  style: const TextStyle(
                                    color: Color(0xFFD2691E),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Attendance Stats Grid
            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                addAutomaticKeepAlives: false, // Better memory management
                addRepaintBoundaries: false, // Reduce repaint boundaries
                children: [
                  _buildAttendanceCardTappable('Present', workingDays, Colors.green, () {
                    // Navigate to calendar when Present card is tapped
                    if (dailyAttendanceData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Loading attendance data... Please wait and try again.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    debugPrint('📅 Navigating to calendar with ${dailyAttendanceData.length} days of data (Present filter)');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceCalendarPage(
                          attendanceData: dailyAttendanceData,
                          filterStatus: 'P', // Filter for Present days only
                          title: 'Present Days',
                        ),
                      ),
                    );
                  }),
                  _buildLeaveCard(), // Special card for Leave with popup
                  _buildAttendanceCardTappable('Absent', absentDays, Colors.red, () {
                    // Navigate to calendar when Absent card is tapped
                    if (dailyAttendanceData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Loading attendance data... Please wait and try again.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    debugPrint('📅 Navigating to calendar with ${dailyAttendanceData.length} days of data (Absent filter)');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceCalendarPage(
                          attendanceData: dailyAttendanceData,
                          filterStatus: 'A', // Filter for Absent days only
                          title: 'Absent Days',
                        ),
                      ),
                    );
                  }),
                  _buildAttendanceCard('On Duty', onDutyCount, Colors.pink),
                  _buildAttendanceCardTappable('Holiday', holidays, const Color(0xFFD4AF37), () { // Gold color
                    // Navigate to calendar when Holiday card is tapped
                    if (dailyAttendanceData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Loading attendance data... Please wait and try again.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    debugPrint('📅 Navigating to calendar with ${dailyAttendanceData.length} days of data (Holiday filter)');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceCalendarPage(
                          attendanceData: dailyAttendanceData,
                          filterStatus: 'H', // Filter for Holiday days only
                          title: 'Holidays',
                        ),
                      ),
                    );
                  }),
                  _buildAttendanceCardTappable('Week Off', weekOffs, Colors.orange, () {
                    // Navigate to calendar when Week Off card is tapped
                    if (dailyAttendanceData.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Loading attendance data... Please wait and try again.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    
                    debugPrint('📅 Navigating to calendar with ${dailyAttendanceData.length} days of data (Week Off filter)');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceCalendarPage(
                          attendanceData: dailyAttendanceData,
                          filterStatus: 'WO', // Filter for Week Off days only
                          title: 'Week Offs',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Live Location Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFD2691E).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFFD2691E),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)?.currentLocation ??
                              'Current Location',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        if (isLocationLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFD2691E)),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Color(0xFFD2691E),
                              size: 20,
                            ),
                            onPressed: _getCurrentLocation,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentLocation,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Leave\nApproval',
                      Icons.approval,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Application\nApproval',
                      Icons.schedule,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      'Employee\nScreen',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            ),

            // Last Punching Section
            GestureDetector(
              onTap: () {
                if (!_hasPunchingPermission) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClockingPage()),
                ).then((_) {
                  // Refresh last punching data when returning from punching page
                  _loadLastClockingData();
                });
              },
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5DC),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)?.lastClocking ??
                            'LAST CLOCKING',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2691E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasLastClocking && lastClockingTime != null)
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEE, MMMM dd, yyyy').format(lastClockingTime!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm a').format(lastClockingTime!),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lastClockingType ?? 'CLOCKED-IN',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lastClockingLocation ?? 'Location not available',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                        ),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                          'No punching records found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by punching in from the Punching page',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(String title, String count, Color color) {
    // Get appropriate icon for each status
    IconData getStatusIcon(String status) {
      switch (status.toLowerCase()) {
        case 'present':
          return Icons.check_circle;
        case 'absent':
          return Icons.cancel;
        case 'on duty':
          return Icons.work;
        case 'holiday':
          return Icons.celebration;
        case 'week off':
          return Icons.weekend;
        default:
          return Icons.info;
      }
    }

    // Create gradient colors based on the main color
    final gradientColors = [
      color,
      color.withOpacity(0.8),
      color.withOpacity(0.9),
    ];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add haptic feedback
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(getStatusIcon(title), color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('$title: $count days'),
                  ],
                ),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Icon container with background
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isLoadingAttendance
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            getStatusIcon(title),
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Text and value on the right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title text with better typography
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Count value with enhanced styling
                        Text(
                          isLoadingAttendance ? '...' : count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tappable attendance card with custom onTap handler
  Widget _buildAttendanceCardTappable(String title, String count, Color color, VoidCallback onTap) {
    // Get appropriate icon for each status
    IconData getStatusIcon(String status) {
      switch (status.toLowerCase()) {
        case 'present':
          return Icons.check_circle;
        case 'absent':
          return Icons.cancel;
        case 'on duty':
          return Icons.work;
        case 'holiday':
          return Icons.celebration;
        case 'week off':
          return Icons.weekend;
        default:
          return Icons.info;
      }
    }

    // Special gradient for Holiday card (gold + red)
    final isHoliday = title.toLowerCase() == 'holiday';
    final gradientColors = isHoliday
        ? [
            const Color(0xFFD4AF37), // Gold
            const Color(0xFFFFD700), // Lighter gold
            const Color(0xFFFF6B6B), // Red accent
          ]
        : [
            color,
            color.withOpacity(0.8),
            color.withOpacity(0.9),
          ];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add haptic feedback
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Icon container with background
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: isLoadingAttendance
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            getStatusIcon(title),
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Text and value on the right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title text with better typography
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Count value with enhanced styling
                        Text(
                          isLoadingAttendance ? '...' : count,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveCard() {
    // Create gradient colors for leave card
    const color = Colors.blue;
    final gradientColors = [
      color,
      color.withOpacity(0.8),
      color.withOpacity(0.9),
    ];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        elevation: 4,
        shadowColor: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Add haptic feedback
            HapticFeedback.lightImpact();
            _showLeaveDetailsPopup();
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Icon container with background
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.time_to_leave,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Text and value on the right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Title
                        const Text(
                          'Leave Balance',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Total — sum of all balances, rounded
                        Text(
                          () {
                            final total = (double.tryParse(balEl) ?? 0.0) +
                                (double.tryParse(balCl) ?? 0.0) +
                                (double.tryParse(balSl) ?? 0.0);
                            final decimal = total - total.truncate();
                            return decimal > 0.5
                                ? total.ceil().toString()
                                : total.floor().toString();
                          }(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLeaveDetailsPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.beach_access, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Leave Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Earned Leave (EL)
                _buildLeaveBalanceCard(
                  'Earned Leave (EL)',
                  balEl,
                  const Color(0xFF06B6D4),
                  const Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                // Casual Leave (CL)
                _buildLeaveBalanceCard(
                  'Casual Leave (CL)',
                  balCl,
                  const Color(0xFF8B5CF6),
                  const Color(0xFFEC4899),
                ),
                const SizedBox(height: 12),
                // Sick Leave (SL)
                _buildLeaveBalanceCard(
                  'Sick Leave (SL)',
                  balSl,
                  const Color(0xFFF59E0B),
                  const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Color(0xFF667EEA),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaveDetailCard(
    String title,
    String total,
    String used,
    String balance,
    Color startColor,
    Color endColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: 0.12),
            endColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: startColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with gradient text effect
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Leave details in a row with better spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: startColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: startColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 40,
                color: startColor.withValues(alpha: 0.2),
              ),
              // Used
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Used',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: startColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      used,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: startColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 40,
                color: startColor.withValues(alpha: 0.2),
              ),
              // Balance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: endColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      balance,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: endColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCard(
    String title,
    String balance,
    Color startColor,
    Color endColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            startColor.withValues(alpha: 0.12),
            endColor.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: startColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [startColor, endColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [startColor, endColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              balance,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color,
      {bool showBadge = false}) {
    return GestureDetector(
      onTap: () {
        // Navigate based on button title
        if (title == 'Leave\nApproval') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveApplicationPage()),
          );
        } else if (title == 'Application\nApproval') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApplicationApprovalPage()),
          );
        } else if (title == 'Employee\nScreen') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmployeePage()),
          );
        } else {
          // For other buttons, show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title pressed')),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
              ),
              if (showBadge)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Drawer(
      child: Container(
        color: isDark ? theme.drawerTheme.backgroundColor : const Color(0xFF2C2C2C),
        child: Column(
          children: [
            // Header with gradient bar
            Container(
              height: 60,
              width: double.infinity,
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
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                      Icons.home,
                      AppLocalizations.of(context)?.dashboard ?? 'Dashboard',
                      true),
                  if (_hasPunchingPermission)
                    _buildDrawerItem(
                        Icons.location_on,
                        AppLocalizations.of(context)?.clocking ?? 'Punching',
                        false),
                  
                  // ESS Section
                  _buildESSSection(),
                  
                  // Visitors Section
                  _buildVisitorsSection(),

                  // Claim & Reimbursement Section
                  _buildClaimSection(),

                  // Policy & Procedure - direct navigation
                  _buildPolicyDrawerItem(),
                  
                  _buildDrawerItem(
                      Icons.settings,
                      AppLocalizations.of(context)?.settings ?? 'Settings',
                      false),
                  _buildDrawerItem(Icons.logout, 'Signout', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildESSSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // ESS Header (expandable)
        Container(
          decoration: BoxDecoration(
            color: isESSExpanded 
                ? (isDark ? Colors.grey[800] : const Color(0xFF404040))
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isESSExpanded ? Colors.blue : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.business_center,
              color: isDark ? Colors.grey[300] : Colors.white70,
              size: 24,
            ),
            title: Text(
              'ESS',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isESSExpanded ? Icons.expand_less : Icons.expand_more,
              color: isDark ? Colors.grey[300] : Colors.white70,
            ),
            onTap: () {
              setState(() {
                isESSExpanded = !isESSExpanded;
              });
            },
          ),
        ),
        
        // ESS Sub-items (collapsible) - using cached items
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: isESSExpanded ? _buildESSContent(isDark) : const SizedBox.shrink(),
        ),
      ],
    );
  }
  
  Widget _buildESSContent(bool isDark) {
    if (!_menuItemsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    if (_essMenuItems != null && _essMenuItems!.isNotEmpty) {
      return Column(children: _essMenuItems!);
    }
    
    // No permissions
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'No ESS permissions available',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.white54,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  /// Build ESS sub-items based on permissions
  Future<List<Widget>> _buildESSSubItems() async {
    final List<Widget> items = [];
    
    // Check permissions for each ESS page
    if (await _hasReadPermission('Daily Attendance')) {
      items.add(_buildESSSubItem(Icons.calendar_today, 'Daily Attendance'));
    }
    
    if (await _hasReadPermission('Application Approval')) {
      items.add(_buildESSSubItem(Icons.approval, 'Application Approval'));
    }
    
    if (await _hasReadPermission('Miss Punch')) {
      items.add(_buildESSSubItem(Icons.punch_clock, 'Miss Punch'));
    }
    
    if (await _hasReadPermission('Leave Application')) {
      items.add(_buildESSSubItem(Icons.event_note, 'Leave Application'));
    }
    
    if (await _hasReadPermission('On Duty')) {
      items.add(_buildESSSubItem(Icons.work, 'On Duty'));
    }
    
    if (await _hasReadPermission('Payslip')) {
      items.add(_buildESSSubItem(Icons.receipt_long, 'Pay Slip'));
    }
    
    if (await _hasReadPermission('Team Attendance')) {
      items.add(_buildESSSubItem(Icons.group, 'Team Attendance'));
    }
    
    if (await _hasReadPermission('WFH')) {
      items.add(_buildESSSubItem(Icons.home_work, 'WFH'));
    }
    
    if (await _hasReadPermission('Comp-Off')) {
      items.add(_buildESSSubItem(Icons.event_available, 'Comp-Off'));
    }
    
    return items;
  }

  Widget _buildESSSubItem(IconData icon, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.white30,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 24, right: 16),
        leading: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.white60,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          
          // Navigate to specific ESS pages
          if (title == 'Daily Attendance') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DailyAttendancePage()),
            );
          } else if (title == 'Application Approval') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ApplicationApprovalPage()),
            );
          } else if (title == 'Miss Punch') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MissPunchPage()),
            );
          } else if (title == 'Leave Application') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LeaveApplicationPage()),
            );
          } else if (title == 'On Duty') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OnDutyPage()),
            );
          } else if (title == 'Comp-Off') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CompOffPage()),
            );
          } else if (title == 'Pay Slip') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PaySlipPage()),
            );
          } else if (title == 'Team Attendance') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TeamAttendancePage()),
            );
          } else if (title == 'WFH') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WFHPage()),
            );
          }
        },
      ),
    );
  }

  Widget _buildVisitorsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // Visitors Header (expandable)
        Container(
          decoration: BoxDecoration(
            color: isVisitorsExpanded 
                ? (isDark ? Colors.grey[800] : const Color(0xFF404040))
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isVisitorsExpanded ? Colors.orange : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.people,
              color: isDark ? Colors.grey[300] : Colors.white70,
              size: 24,
            ),
            title: Text(
              'Visitors',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isVisitorsExpanded ? Icons.expand_less : Icons.expand_more,
              color: isDark ? Colors.grey[300] : Colors.white70,
            ),
            onTap: () {
              setState(() {
                isVisitorsExpanded = !isVisitorsExpanded;
              });
            },
          ),
        ),
        
        // Visitors Sub-items (collapsible) - using cached items
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: isVisitorsExpanded ? _buildVisitorsContent(isDark) : const SizedBox.shrink(),
        ),
      ],
    );
  }
  
  Widget _buildVisitorsContent(bool isDark) {
    if (!_menuItemsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    if (_visitorsMenuItems != null && _visitorsMenuItems!.isNotEmpty) {
      return Column(children: _visitorsMenuItems!);
    }
    
    // No permissions
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'No Visitors permissions available',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.white54,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  /// Build Visitors sub-items based on permissions
  Future<List<Widget>> _buildVisitorsSubItems() async {
    final List<Widget> items = [];
    
    // Check permissions for each Visitors page
    if (await _hasReadPermission('Employee Screen')) {
      items.add(_buildVisitorsSubItem(Icons.person, 'Employee Screen'));
    }
    
    // Security Screen page not implemented yet - hiding for now
    // if (await _hasReadPermission('Security Screen')) {
    //   items.add(_buildVisitorsSubItem(Icons.security, 'Security Screen'));
    // }
    
    return items;
  }

  Widget _buildVisitorsSubItem(IconData icon, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.white30,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 24, right: 16),
        leading: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.white60,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          
          // Navigate to specific Visitors pages
          if (title == 'Employee Screen') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeePage()),
            );
          }
        },
      ),
    );
  }

  // Claim & Reimbursement Section
  Widget _buildClaimSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // Claim & Reimbursement Header (expandable)
        Container(
          decoration: BoxDecoration(
            color: isClaimExpanded 
                ? (isDark ? Colors.grey[800] : const Color(0xFF404040))
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isClaimExpanded ? Colors.teal : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.receipt,
              color: isDark ? Colors.grey[300] : Colors.white70,
              size: 24,
            ),
            title: Text(
              'Claim & Reimbursement',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(
              isClaimExpanded ? Icons.expand_less : Icons.expand_more,
              color: isDark ? Colors.grey[300] : Colors.white70,
            ),
            onTap: () {
              setState(() {
                isClaimExpanded = !isClaimExpanded;
              });
            },
          ),
        ),
        
        // Claim & Reimbursement Sub-items (collapsible) - using cached items
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: isClaimExpanded ? _buildClaimContent(isDark) : const SizedBox.shrink(),
        ),
      ],
    );
  }
  
  Widget _buildClaimContent(bool isDark) {
    if (!_menuItemsLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    
    if (_claimMenuItems != null && _claimMenuItems!.isNotEmpty) {
      return Column(children: _claimMenuItems!);
    }
    
    // No permissions
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        'No Claim & Reimbursement permissions available',
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.white54,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  /// Build Claim & Reimbursement sub-items based on permissions
  Future<List<Widget>> _buildClaimSubItems() async {
    final List<Widget> items = [];

    // Check permissions for each Claim & Reimbursement page
    if (await _hasReadPermission('Travel Claim')) {
      items.add(_buildClaimSubItem(Icons.flight, 'Travel Claim'));
    }

    if (await _hasReadPermission('General Expense')) {
      items.add(_buildClaimSubItem(Icons.account_balance_wallet, 'General Expense'));
    }

    if (await _hasReadPermission('Conveyance Claim')) {
      items.add(_buildClaimSubItem(Icons.directions_car, 'Conveyance Claim'));
    }

    if (await _hasReadPermission('Reimbursement')) {
      items.add(_buildClaimSubItem(Icons.receipt, 'Reimbursement'));
    }

    if (await _hasReadPermission('Claim Approval')) {
      items.add(_buildClaimSubItem(Icons.task_alt, 'Claim Approval'));
    }

    return items;
  }

  Widget _buildClaimSubItem(IconData icon, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.white30,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 24, right: 16),
        leading: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.white60,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);

          // Navigate to specific Claim & Reimbursement pages
          if (title == 'Travel Claim') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TravelClaimPage()),
            );
          } else if (title == 'General Expense') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GeneralExpensePage()),
            );
          } else if (title == 'Conveyance Claim') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ConveyanceClaimPage()),
            );
          } else if (title == 'Reimbursement') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReimbursementPage()),
            );
          } else if (title == 'Claim Approval') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClaimApprovalPage()),
            );
          }
        },
      ),
    );
  }

  Widget _buildPolicyDrawerItem() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        Icons.policy,
        color: isDark ? Colors.grey[300] : Colors.white70,
        size: 24,
      ),
      title: Text(
        'Policy & Procedure',
        style: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PolicyProcedurePage()),
        );
      },
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isSelected 
          ? (isDark ? Colors.grey[800] : const Color(0xFF404040))
          : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark 
              ? (isSelected ? Colors.white : Colors.grey[300])
              : Colors.white70,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark 
                ? (isSelected ? Colors.white : Colors.grey[300])
                : (isSelected ? Colors.white : Colors.white70),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);

          // Navigate to specific pages
          final localizations = AppLocalizations.of(context);
          if (title == (localizations?.clocking ?? 'Punching')) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClockingPage()),
            ).then((_) {
              // Refresh last clocking data when returning from clocking page
              _loadLastClockingData();
            });
          } else if (title == (localizations?.settings ?? 'Settings')) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          } else if (title == 'Signout') {
            _showLogoutDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title selected')),
            );
          }
        },
      ),
    );
  }
}
