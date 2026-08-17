import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service to provide comprehensive dummy data for test user 'SSIS001'
class DummyDataService {
  static const String testUsername = 'SSIS001';
  static const String testPassword = 'SSIS001';
  
  /// Check if current user is the test user
  static Future<bool> isTestUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email') ?? '';
      return userEmail == testUsername;
    } catch (e) {
      return false;
    }
  }
  
  /// Initialize dummy data for test user login
  static Future<void> initializeDummyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Basic user data
      await prefs.setString('user_email', testUsername);
      await prefs.setString('user_id', 'EMP001');
      await prefs.setString('user_name', 'Rajesh Kumar Singh');
      await prefs.setString('username', testUsername);
      await prefs.setString('emp_paycode', testUsername);
      
      // Login session data
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('login_time', DateTime.now().toIso8601String());
      
      // Attendance data for current month
      await prefs.setString('attendance_working_days', '18');
      await prefs.setString('attendance_absent_days', '2');
      await prefs.setString('attendance_holidays', '3');
      await prefs.setString('attendance_week_offs', '8');
      
      // Leave data
      await prefs.setString('leave_el_used', '5');
      await prefs.setString('leave_sl_used', '2');
      await prefs.setString('leave_cl_used', '1');
      await prefs.setString('leave_total', '8');
      
      // Leave balance data
      await prefs.setString('leave_el_balance', '15');
      await prefs.setString('leave_sl_balance', '10');
      await prefs.setString('leave_cl_balance', '11');
      
      // Current clocking status (checked in)
      await prefs.setBool('is_clocked_in', true);
      await prefs.setBool('is_currently_clocked_in', true);
      final checkInTime = DateTime.now().subtract(const Duration(hours: 4, minutes: 30));
      await prefs.setString('current_check_in_time', checkInTime.toIso8601String());
      await prefs.setString('current_check_in_location', 'Office Main Building, Sector 62, Noida');
      await prefs.setString('current_check_in_coordinates', '28.6139,77.2090');
      
      // Work duration
      const workDurationSeconds = 4 * 3600 + 30 * 60; // 4.5 hours
      await prefs.setString('current_work_duration', workDurationSeconds.toString());
      
      // Permissions data
      await prefs.setString('user_permissions', jsonEncode(getDummyPermissions()));
      
      // Check-in/out data for the month
      await prefs.setString('checkin_checkout_data', jsonEncode(getDummyCheckInOutData()));
      
      // Daily attendance data for calendar
      await prefs.setString('daily_attendance_data', jsonEncode(getDummyDailyAttendanceData()));
      
      debugPrint('✅ Dummy data initialized for test user: $testUsername');
    } catch (e) {
      debugPrint('❌ Error initializing dummy data: $e');
    }
  }
  
  /// Get dummy permissions for test user
  static Map<String, dynamic> getDummyPermissions() {
    return {
      'module': 'ESS',
      'permissions': [
        {'name': 'attendance_view', 'allowed': true},
        {'name': 'leave_application', 'allowed': true},
        {'name': 'miss_punch', 'allowed': true},
        {'name': 'on_duty', 'allowed': true},
        {'name': 'payslip_view', 'allowed': false}, // No payslip permission for test user
        {'name': 'team_attendance', 'allowed': true},
        {'name': 'application_approval', 'allowed': true},
        {'name': 'employee_management', 'allowed': false},
        {'name': 'visitor_management', 'allowed': false},
      ]
    };
  }
  
  /// Get dummy check-in/out data for current month
  static Map<String, dynamic> getDummyCheckInOutData() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    // Generate attendance data for the current month
    final List<Map<String, dynamic>> attendanceRecords = [];
    
    // Add records for working days in current month
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(currentYear, currentMonth, day);
      
      // Skip weekends for most days
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        if (day % 7 == 0) { // Occasional weekend work
          attendanceRecords.add(_generateAttendanceRecord(date, isWeekend: true));
        }
        continue;
      }
      
      // Skip some days as holidays/leaves
      if (day == 15 || day == 26) continue; // Holidays
      if (day == 8 || day == 22) continue; // Leave days
      
      attendanceRecords.add(_generateAttendanceRecord(date));
    }
    
    return {
      'status': 'success',
      'data': [{
        'emp_paycode': testUsername,
        'emp_name': 'Rajesh Kumar Singh',
        'working_days': 18,
        'absent_days': 2,
        'holidays': 3,
        'week_offs': 8,
        'el_used': 5,
        'sl_used': 2,
        'cl_used': 1,
        'attendance_records': attendanceRecords,
      }]
    };
  }
  
  /// Generate a single attendance record
  static Map<String, dynamic> _generateAttendanceRecord(DateTime date, {bool isWeekend = false}) {
    // Generate realistic check-in times (8:30 AM to 10:00 AM)
    final checkInHour = 8 + (date.day % 2); // Alternate between 8 and 9
    final checkInMinute = 30 + (date.day % 30); // Vary minutes
    final checkInTime = DateTime(date.year, date.month, date.day, checkInHour, checkInMinute);
    
    // Generate check-out times (5:30 PM to 7:00 PM)
    final checkOutHour = 17 + (date.day % 2); // Alternate between 17 and 18
    final checkOutMinute = 30 + (date.day % 30); // Vary minutes
    final checkOutTime = DateTime(date.year, date.month, date.day, checkOutHour, checkOutMinute);
    
    // Calculate work duration
    final workDuration = checkOutTime.difference(checkInTime);
    final workHours = workDuration.inHours;
    final workMinutes = workDuration.inMinutes % 60;
    
    return {
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'check_in_time': '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
      'check_out_time': '${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')}',
      'work_duration': '${workHours}h ${workMinutes}m',
      'location': isWeekend ? 'Home Office' : 'Office Main Building, Sector 62, Noida',
      'status': isWeekend ? 'Weekend Work' : 'Present',
      'overtime': workHours > 8 ? '${workHours - 8}h ${workMinutes}m' : '0h 0m',
    };
  }
  
  /// Get dummy daily attendance data for calendar view
  static Map<String, String> getDummyDailyAttendanceData() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final Map<String, String> dailyData = {};
    
    for (int day = 1; day <= now.day; day++) {
      final date = DateTime(currentYear, currentMonth, day);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        if (day % 7 == 0) {
          dailyData[dateKey] = 'Weekend Work';
        } else {
          dailyData[dateKey] = 'Weekend';
        }
      } else if (day == 15 || day == 26) {
        dailyData[dateKey] = 'Holiday';
      } else if (day == 8 || day == 22) {
        dailyData[dateKey] = 'Leave';
      } else {
        dailyData[dateKey] = 'Present';
      }
    }
    
    return dailyData;
  }
  
  /// Get dummy leave applications
  static List<Map<String, dynamic>> getDummyLeaveApplications() {
    return [
      {
        'id': 'LA001',
        'applicationType': 'Leave',
        'leaveType': 'Earned Leave',
        'fromDate': '2026-03-08',
        'toDate': '2026-03-08',
        'dayPart': 'Full Day',
        'dayCount': '1',
        'applicationStatus': 'Approved',
        'reason': 'Personal work',
        'appliedOn': '2026-03-05',
        'approvedRejectedOn': '2026-03-06',
        'cancelledOn': '',
        'approvedRejectedBy': 'Manager Name',
        'remarks': 'Approved for personal work',
        'attachment': '',
      },
      {
        'id': 'LA002',
        'applicationType': 'Leave',
        'leaveType': 'Sick Leave',
        'fromDate': '2026-02-22',
        'toDate': '2026-02-22',
        'dayPart': 'Full Day',
        'dayCount': '1',
        'applicationStatus': 'Approved',
        'reason': 'Fever and cold',
        'appliedOn': '2026-02-21',
        'approvedRejectedOn': '2026-02-21',
        'cancelledOn': '',
        'approvedRejectedBy': 'Manager Name',
        'remarks': 'Medical leave approved',
        'attachment': '',
      },
      {
        'id': 'LA003',
        'applicationType': 'Leave',
        'leaveType': 'Casual Leave',
        'fromDate': '2026-03-20',
        'toDate': '2026-03-21',
        'dayPart': 'Full Day',
        'dayCount': '2',
        'applicationStatus': 'Pending',
        'reason': 'Family function',
        'appliedOn': '2026-03-10',
        'approvedRejectedOn': '',
        'cancelledOn': '',
        'approvedRejectedBy': '',
        'remarks': '',
        'attachment': '',
      },
    ];
  }
  
  /// Get dummy miss punch applications
  static List<Map<String, dynamic>> getDummyMissPunchApplications() {
    return [
      {
        'id': 'MP001',
        'applicationType': 'Miss Punch',
        'date': '2026-03-05',
        'punchType': 'Check Out',
        'time': '18:30',
        'reason': 'Forgot to punch out',
        'applicationStatus': 'Approved',
        'appliedOn': '2026-03-06',
        'approvedRejectedBy': 'Manager Name',
        'approvedRejectedOn': '2026-03-06',
        'remarks': 'Approved - valid reason',
      },
      {
        'id': 'MP002',
        'applicationType': 'Miss Punch',
        'date': '2026-02-28',
        'punchType': 'Check In',
        'time': '09:15',
        'reason': 'System was down',
        'applicationStatus': 'Pending',
        'appliedOn': '2026-03-01',
        'approvedRejectedBy': '',
        'approvedRejectedOn': '',
        'remarks': '',
      },
    ];
  }
  
  /// Get dummy on-duty applications
  static List<Map<String, dynamic>> getDummyOnDutyApplications() {
    return [
      {
        'id': 'OD001',
        'applicationType': 'On Duty',
        'date': '2026-03-15',
        'fromTime': '10:00',
        'toTime': '16:00',
        'purpose': 'Client meeting at Delhi office',
        'location': 'Delhi Office, Connaught Place',
        'applicationStatus': 'Approved',
        'appliedOn': '2026-03-12',
        'approvedRejectedBy': 'Manager Name',
        'approvedRejectedOn': '2026-03-13',
        'remarks': 'Approved for client meeting',
      },
      {
        'id': 'OD002',
        'applicationType': 'On Duty',
        'date': '2026-03-25',
        'fromTime': '14:00',
        'toTime': '18:00',
        'purpose': 'Training session at partner office',
        'location': 'Partner Office, Gurgaon',
        'applicationStatus': 'Pending',
        'appliedOn': '2026-03-10',
        'approvedRejectedBy': '',
        'approvedRejectedOn': '',
        'remarks': '',
      },
    ];
  }
  
  /// Get dummy payslip data
  static Map<String, dynamic> getDummyPayslipData() {
    return {
      'pay_code': testUsername,
      'name': 'Rajesh Kumar Singh',
      'f_name': 'Suresh Kumar Singh',
      'des_name': 'Senior Software Engineer',
      'dep_name': 'Information Technology',
      'adh_no': '1234-5678-9012',
      'doj1': '2022-06-15',
      'bank_name': 'State Bank of India',
      'bank_no': '12345678901',
      'pf_no': 'DL/12345/67890',
      'uan': '123456789012',
      'pay_mode': 'Bank Transfer',
      'esi_no': '1234567890',
      'pan': 'ABCDE1234F',
      'cmp_name': 'DELTON CABLES LIMITED (HO)',
      'unit_name': 'HO',
      'address': '17/4 MATHURA ROAD SEC-16A FARIDABAD HARYANA 121001',
      'wday': 26,
      'wf': 4,
      'hd': 2,
      'cl': 1,
      'el': 1,
      'sl': 0,
      'ml': 0,
      'coff': 0,
      'pday': 28,
      'rat1': 45000.00, // Basic
      'rat2': 18000.00, // HRA
      'rat3': 12000.00, // Conv Allow
      'rat4': 1500.00,  // Med Allow
      'rat5': 2000.00,  // Spl Allow
      'rat6': 0.00,     // Others
      'earn1': 45000.00,
      'earn2': 18000.00,
      'earn3': 12000.00,
      'earn4': 1500.00,
      'earn5': 2000.00,
      'earn6': 0.00,
      'total1': 45000.00,
      'total2': 18000.00,
      'total3': 12000.00,
      'total4': 1500.00,
      'total5': 2000.00,
      'total6': 0.00,
      'ded1': 5400.00, // PF
      'ded2': 275.00,  // ESI
      'total_salary': 78500.00,
      'tot_sal': 78500.00,
      'tot_ded': 5675.00,
      'net_sal': 72825.00,
    };
  }
  
  /// Get dummy team attendance data
  static List<Map<String, dynamic>> getDummyTeamAttendanceData() {
    return [
      {
        'emp_id': 'EMP002',
        'name': 'Priya Sharma',
        'designation': 'Software Engineer',
        'status': 'Present',
        'check_in_time': '09:15',
        'check_out_time': '',
        'work_duration': '4h 45m',
        'location': 'Office Main Building',
      },
      {
        'emp_id': 'EMP003',
        'name': 'Amit Patel',
        'designation': 'Senior Developer',
        'status': 'Present',
        'check_in_time': '08:45',
        'check_out_time': '',
        'work_duration': '5h 15m',
        'location': 'Office Main Building',
      },
      {
        'emp_id': 'EMP004',
        'name': 'Sneha Gupta',
        'designation': 'QA Engineer',
        'status': 'On Leave',
        'check_in_time': '',
        'check_out_time': '',
        'work_duration': '',
        'location': '',
      },
      {
        'emp_id': 'EMP005',
        'name': 'Rohit Singh',
        'designation': 'DevOps Engineer',
        'status': 'Present',
        'check_in_time': '09:30',
        'check_out_time': '18:15',
        'work_duration': '8h 45m',
        'location': 'Office Main Building',
      },
    ];
  }
  
  /// Get dummy application approval data
  static List<Map<String, dynamic>> getDummyApplicationApprovalData() {
    return [
      {
        'id': 'APP001',
        'type': 'Leave Application',
        'employee_name': 'Priya Sharma',
        'employee_id': 'EMP002',
        'application_type': 'Earned Leave',
        'from_date': '2026-03-18',
        'to_date': '2026-03-19',
        'days': 2,
        'reason': 'Family wedding',
        'status': 'Pending',
        'applied_date': '2026-03-10',
        'department': 'Information Technology',
      },
      {
        'id': 'APP002',
        'type': 'Miss Punch',
        'employee_name': 'Amit Patel',
        'employee_id': 'EMP003',
        'application_type': 'Check Out',
        'date': '2026-03-11',
        'time': '18:00',
        'reason': 'System malfunction',
        'status': 'Pending',
        'applied_date': '2026-03-12',
        'department': 'Information Technology',
      },
      {
        'id': 'APP003',
        'type': 'On Duty',
        'employee_name': 'Rohit Singh',
        'employee_id': 'EMP005',
        'application_type': 'Client Visit',
        'from_time': '14:00',
        'to_time': '17:00',
        'date': '2026-03-20',
        'purpose': 'Client presentation at Gurgaon office',
        'status': 'Pending',
        'applied_date': '2026-03-12',
        'department': 'Information Technology',
      },
    ];
  }
  
  /// Get dummy employee/visitor data
  static List<Map<String, dynamic>> getDummyEmployeeVisitorData() {
    return [
      {
        'id': 'V001',
        'type': 'Visitor',
        'name': 'Suresh Kumar',
        'phone_no': '+91-9876543210',
        'unit': 'IT Department',
        'company': 'Tech Solutions Pvt Ltd',
        'address': 'Sector 18, Noida',
        'email': 'suresh@techsolutions.com',
        'person_to_meet': 'Rajesh Kumar Singh',
        'employee_code': testUsername,
        'department': 'Information Technology',
        'doc_type': 'Aadhar Card',
        'doc_number': '1234-5678-9012',
        'purpose': 'Business meeting for new project discussion',
        'status': 'Pending',
        'created_at': '12-03-2026 10:30',
        'time_approved': '',
        'reject_reason': '',
        'is_vip': false,
      },
      {
        'id': 'V002',
        'type': 'Contractor',
        'name': 'Manoj Electrician',
        'phone_no': '+91-9876543211',
        'unit': 'Maintenance',
        'company': 'Electrical Services',
        'address': 'Sector 62, Noida',
        'email': 'manoj@electrical.com',
        'person_to_meet': 'Facility Manager',
        'employee_code': 'FAC001',
        'department': 'Facilities',
        'doc_type': 'Driving License',
        'doc_number': 'DL-0123456789',
        'purpose': 'Electrical maintenance work',
        'status': 'Approved',
        'created_at': '11-03-2026 14:15',
        'time_approved': '11-03-2026 14:30',
        'reject_reason': '',
        'is_vip': false,
      },
    ];
  }
  
  /// Get dummy profile data
  static Map<String, dynamic> getDummyProfileData() {
    return {
      'employee_id': testUsername,
      'name': 'Rajesh Kumar Singh',
      'email': 'rajesh.singh@company.com',
      'phone': '+91-9876543210',
      'designation': 'Senior Software Engineer',
      'department': 'Information Technology',
      'reporting_manager': 'Vikash Sharma',
      'date_of_joining': '15-06-2022',
      'employee_type': 'Permanent',
      'location': 'Noida Office',
      'address': 'H-123, Sector 15, Noida, UP - 201301',
      'emergency_contact': '+91-9876543211',
      'blood_group': 'B+',
      'pan_number': 'ABCDE1234F',
      'aadhar_number': '1234-5678-9012',
    };
  }
  
  /// Clear all dummy data
  static Future<void> clearDummyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all stored data
      final keys = [
        'user_email', 'user_id', 'user_name', 'username', 'emp_paycode',
        'is_logged_in', 'login_time', 'attendance_working_days', 'attendance_absent_days',
        'attendance_holidays', 'attendance_week_offs', 'leave_el_used', 'leave_sl_used',
        'leave_cl_used', 'leave_total', 'leave_el_balance', 'leave_sl_balance',
        'leave_cl_balance', 'is_clocked_in', 'is_currently_clocked_in',
        'current_check_in_time', 'current_check_in_location', 'current_check_in_coordinates',
        'current_work_duration', 'user_permissions', 'checkin_checkout_data',
        'daily_attendance_data'
      ];
      
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      debugPrint('✅ Dummy data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing dummy data: $e');
    }
  }
}