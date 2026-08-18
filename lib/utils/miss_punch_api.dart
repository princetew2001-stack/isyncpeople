import 'dart:convert';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class MissPunchApiService {
  static const String _missPunchEndpoint = 'https://delton.intellisync.in:11004/ess/miss-punch-application/';
  
  final AuthService _authService = AuthService();

  /// Fetch miss punch applications from the API
  Future<List<Map<String, dynamic>>> fetchMissPunchApplications() async {
    try {
      debugPrint('🔗 Starting miss punch API call...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy miss punch applications');
        return DummyDataService.getDummyMissPunchApplications();
      }
      
      // Get employee paycode
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        debugPrint('❌ No employee paycode found');
        throw Exception('Employee ID not found. Please login again.');
      }
      
      debugPrint('📱 Employee paycode: $empPaycode');
      
      // Construct the API endpoint
      const endpoint = 'https://delton.intellisync.in:11004/ess/miss-punch-application/?json=true';
      debugPrint('🔗 Fetching miss punch data from: $endpoint');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 API Response status: ${response.statusCode}');
      // Note: Response body logged only for debugging when needed
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Miss punch data fetched successfully');
        
        // Parse the response data
        if (responseData['leave_list'] != null) {
          final List<dynamic> dataList = responseData['leave_list'];
          debugPrint('📊 Found ${dataList.length} miss punch applications');
          
          final List<Map<String, dynamic>> missPunchList = dataList.map((item) {
            // Format date from ISO string to DD-MM-YYYY.
            //
            // The server stores dates in IST (+05:30) and may return them either as:
            //   "2026-06-12T00:00:00+05:30"  → date part before T is correct
            //   "2026-06-11T18:30:00Z"        → UTC midnight IST; naive split gives wrong day
            //
            // Strategy: if the string has an explicit +HH:MM offset, trust the date
            // component before T. If it ends with Z (UTC), parse fully and convert to
            // local time so the day matches what the user entered.
            String formatDate(String? isoDate) {
              if (isoDate == null || isoDate.isEmpty) return '';
              try {
                String datePart;

                final hasPositiveOffset = RegExp(r'\+\d{2}:\d{2}$').hasMatch(isoDate);
                final hasNegativeOffset = RegExp(r'-\d{2}:\d{2}$').hasMatch(isoDate);
                final isUtcZ = isoDate.toUpperCase().endsWith('Z');

                if (hasPositiveOffset || hasNegativeOffset) {
                  // Explicit offset present — the calendar date before 'T' is
                  // already in that timezone, so use it directly.
                  datePart = isoDate.split('T')[0].split(' ')[0];
                } else if (isUtcZ) {
                  // UTC timestamp — parse and convert to local device time so the
                  // displayed day matches the IST date the user originally picked.
                  final utcDt = DateTime.parse(isoDate); // parsed as UTC
                  final local = utcDt.toLocal();
                  datePart =
                      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
                } else {
                  // No timezone info — treat as plain date or local datetime
                  datePart = isoDate.split('T')[0].split(' ')[0];
                }

                final parts = datePart.split('-');
                if (parts.length == 3) {
                  return '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}';
                }
                return isoDate;
              } catch (e) {
                debugPrint('Error parsing date: $isoDate, error: $e');
                return isoDate;
              }
            }

            // Use updated_by_name directly from the API response
            final approverName = item['updated_by_name']?.toString() ?? '';

            return {
              'id': item['id']?.toString() ?? '',
              'applicationType': item['application_type'] ?? 'Miss Punch',
              'missPunchDate': formatDate(item['from_date']),
              'missPunchTime': item['time'] ?? '',
              'dayPart': item['day_part'] ?? '',
              'reason': item['reason'] ?? '',
              'applicationStatus': item['status'] ?? '',
              'appliedOn': formatDate(item['applied_on']),
              'approvedRejectedOn': formatDate(item['approved_on']),
              'cancelledOn': formatDate(item['cancelled_on']),
              'approvedRejectedBy': approverName,
              'remarks': item['remarks'] ?? '',
            };
          }).toList();
          
          debugPrint('✅ Successfully parsed ${missPunchList.length} miss punch applications');
          return missPunchList;
        } else {
          debugPrint('⚠️ No leave_list field found in response');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to load miss punch data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in fetchMissPunchApplications: $e');
      rethrow;
    }
  }

  /// Initialize session for new miss punch application (call when "Add New" is clicked)
  Future<bool> initializeSession() async {
    try {
      debugPrint('🔄 Initializing session for new miss punch application...');
      
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo != null) {
        debugPrint('✅ Session initialized successfully');
        debugPrint('🔐 Session ID: ${sessionInfo['sessionid']?.substring(0, 8)}...');
        debugPrint('🔐 CSRF Token: ${sessionInfo['csrf_token']?.substring(0, 8)}...');
        return true;
      } else {
        debugPrint('❌ Failed to initialize session');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error initializing session: $e');
      return false;
    }
  }

  /// Submit a new miss punch application
  Future<bool> submitMissPunchApplication({
    required String missPunchDate,
    required String missPunchTime,
    required String dayPart,
    required String reason,
    required String department,
  }) async {
    try {
      debugPrint('🔄 Submitting miss punch application...');
      
      // Always fetch fresh CSRF token before submitting to avoid 403 errors
      debugPrint('🔄 Fetching fresh CSRF token for miss punch submission...');
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo == null || sessionInfo['csrf_token'] == null) {
        debugPrint('❌ Failed to get fresh CSRF token');
        throw Exception('Failed to initialize session. Please try again.');
      }
      
      debugPrint('✅ Got fresh CSRF token for submission');
      
      // Validate input parameters
      if (missPunchDate.isEmpty || missPunchTime.isEmpty) {
        debugPrint('❌ Date/Time validation failed: date=$missPunchDate, time=$missPunchTime');
        throw Exception('Miss punch date and time are required');
      }
      
      if (dayPart.isEmpty || reason.isEmpty) {
        debugPrint('❌ Field validation failed: dayPart=$dayPart, reason=$reason');
        throw Exception('Day part and reason are required');
      }
      
      debugPrint('📝 Input parameters:');
      debugPrint('   - missPunchDate: $missPunchDate');
      debugPrint('   - missPunchTime: $missPunchTime');
      debugPrint('   - dayPart: $dayPart');
      debugPrint('   - reason: $reason');
      debugPrint('   - department: $department');
      
      // Prepare form data with the exact format you specified
      final formData = {
        'leave_from': missPunchDate,       // from_date = request.POST.get("leave_from")
        'miss_punch_in': missPunchTime,    // mis_in_time = request.POST.get("miss_punch_in")
        'day_part': dayPart,               // day_part = request.POST.get("day_part")
        'reason': reason,                  // reason = request.POST.get("reason")
        'department': department,          // department = request.POST.get("department")
      };
      
      debugPrint('📤 Final form data being sent to server:');
      debugPrint('   $formData');
      
      // Make authenticated form request using stored session ID and CSRF token
      final response = await _authService.authenticatedFormRequest(
        endpoint: _missPunchEndpoint,
        formData: formData,
      );
      
      debugPrint('📊 Submit Response status: ${response.statusCode}');
      debugPrint('📋 Submit Response headers: ${response.headers}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      // Log response body for 500 errors to help debug server issues
      if (response.statusCode == 500) {
        debugPrint('❌ Server Error (500) - Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }
      
      // Handle successful responses (200, 201) and redirects (302, 301)
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('✅ Miss punch application submitted successfully');
          debugPrint('� dSubmit response: $responseData');
          
          // Check if submission was successful
          if (responseData['success'] == true || responseData['status'] == 'success') {
            debugPrint('✅ Application submission confirmed');
            return true;
          } else {
            debugPrint('⚠️ Application submission may have failed: $responseData');
            return false;
          }
        } catch (e) {
          // If response is not JSON, assume success based on status code
          debugPrint('✅ Miss punch application submitted successfully (non-JSON response)');
          return true;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect - check for error messages in cookies
        debugPrint('🔄 Received redirect response (${response.statusCode})');
        final location = response.headers['location'];
        debugPrint('🔄 Redirect location: $location');
        
        // Check for Django messages in cookies to determine if it's success or error
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && setCookie.contains('messages=')) {
          debugPrint('📨 Server sent a message in redirect');
          debugPrint('🔍 Cookie content: $setCookie');
          
          // Try to decode the message to check if it's a success or error
          final cookieValue = setCookie.toLowerCase();
          
          if (cookieValue.contains('success') || 
              cookieValue.contains('saved') || 
              cookieValue.contains('submitted') ||
              cookieValue.contains('created') ||
              cookieValue.contains('successfully')) {
            debugPrint('✅ Success message detected in redirect');
            return true;
          } else if (cookieValue.contains('miss punch already applied') ||
                     cookieValue.contains('already applied for same date') ||
                     cookieValue.contains('miss%20punch%20already%20applied') ||
                     cookieValue.contains('already%20applied%20for%20same%20date') ||
                     // Check in the base64 encoded content as well
                     (cookieValue.contains('miss') && cookieValue.contains('already'))) {
            debugPrint('❌ Duplicate application error detected');
            throw Exception('Miss punch already applied for the selected date. Please choose a different date.');
          } else if (cookieValue.contains('error') || 
                     cookieValue.contains('failed') || 
                     cookieValue.contains('invalid') ||
                     cookieValue.contains('required')) {
            debugPrint('❌ Error message detected in redirect');
            throw Exception('Miss punch application validation failed. Please check your input and try again.');
          } else {
            debugPrint('⚠️ Unknown message type in redirect, assuming success');
            return true;
          }
        }
        
        // If no messages, then it's a successful redirect
        debugPrint('✅ Form submitted successfully (redirect without error messages)');
        return true;
      } else if (response.statusCode == 403) {
        debugPrint('❌ Authentication failed (403 Forbidden)');
        debugPrint('📄 Response body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        
        // Check if it's a CSRF token issue
        if (response.body.contains('CSRF') || response.body.contains('csrf')) {
          throw Exception('CSRF token validation failed. Please try logging out and logging back in.');
        }
        
        throw Exception('Authentication failed. Please login again.');
      } else {
        debugPrint('❌ Submit API Error: ${response.statusCode}');
        throw Exception('Failed to submit miss punch application. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Network error in submitMissPunchApplication: $e');
      rethrow;
    }
  }

  /// Fetch available miss punch dates for the employee
  Future<List<DateTime>> fetchAvailableMissPunchDates() async {
    try {
      debugPrint('🔗 Starting available miss punch dates fetch...');
      
      // Get numeric emp_code from checkin_checkout_data saved in SharedPreferences
      final empCode = await _authService.getEmpPaycode();
      if (empCode == null || empCode.isEmpty) {
        debugPrint('❌ No emp_code found');
        throw Exception('Employee code not found. Please login again.');
      }
      
      debugPrint('📱 Using emp_code for dates API: $empCode');
      
      // Construct the API endpoint — URL param is <int:emp_code>
      final endpoint = 'https://delton.intellisync.in:11004/ess/miss-punch-dates/$empCode/';
      debugPrint('🔗 Fetching available dates from: $endpoint');

      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Available dates API Response status: ${response.statusCode}');
      // Only log body on error, and truncate HTML responses
      if (response.statusCode != 200) {
        final body = response.body;
        final isHtml = body.trimLeft().startsWith('<');
        debugPrint('📄 Available dates error body: ${isHtml ? "[HTML response - ${body.length} chars]" : body.substring(0, body.length > 200 ? 200 : body.length)}');
      }
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Available dates fetched successfully');
        
        // Parse the dates from the response
        List<DateTime> availableDates = [];
        
        if (responseData is Map && responseData['allowed_dates'] != null) {
          // Response format: {"allowed_dates": ["2025-10-02", "2025-10-07", ...]}
          final datesList = responseData['allowed_dates'] as List;
          for (var dateStr in datesList) {
            final dt = _parseDateSafe(dateStr.toString());
            if (dt != null) availableDates.add(dt);
          }
        } else if (responseData is List) {
          for (var dateStr in responseData) {
            final dt = _parseDateSafe(dateStr.toString());
            if (dt != null) availableDates.add(dt);
          }
        } else if (responseData is Map && responseData['dates'] != null) {
          final datesList = responseData['dates'] as List;
          for (var dateStr in datesList) {
            final dt = _parseDateSafe(dateStr.toString());
            if (dt != null) availableDates.add(dt);
          }
        }
        
        debugPrint('📅 Found ${availableDates.length} available dates');
        for (var date in availableDates) {
          debugPrint('   - ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
        }
        
        return availableDates;
      } else {
        debugPrint('❌ Available dates API Error: ${response.statusCode}');
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to load available dates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in fetchAvailableMissPunchDates: $e');
      rethrow;
    }
  }

  /// Fetch employee data for miss punch form
  Future<Map<String, dynamic>?> fetchEmployeeData() async {
    try {
      debugPrint('🔗 Starting employee data fetch...');
      
      // Get emp_paycode from SharedPreferences (saved during login)
      final empPaycode = await _authService.getEmpPaycode();
      if (empPaycode == null || empPaycode.isEmpty) {
        debugPrint('❌ No emp_paycode found');
        throw Exception('Employee ID not found. Please login again.');
      }
      
      debugPrint('📱 Employee paycode: $empPaycode');
      
      // Pass emp_paycode as query param so the server returns the correct employee object
      final endpoint = 'https://delton.intellisync.in:11004/ess/miss-punch-application/?json=true&emp_paycode=$empPaycode';
      debugPrint('🔗 Fetching employee data from: $endpoint');

      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Employee API Response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        final body = response.body;
        final isHtml = body.trimLeft().startsWith('<');
        debugPrint('📄 Employee API error: ${isHtml ? "[HTML response - ${body.length} chars]" : body.substring(0, body.length > 200 ? 200 : body.length)}');
      }
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Employee data fetched successfully');
        
        // Extract employee data from the response
        if (responseData['employee'] != null) {
          final employeeData = responseData['employee'];
          debugPrint('👤 Employee data found: $employeeData');
          debugPrint('🔑 emp_code: ${employeeData['emp_code']}, emp_paycode: ${employeeData['emp_paycode']}');
          
          return {
            'emp_code': employeeData['emp_code']?.toString() ?? '',
            'emp_paycode': employeeData['emp_paycode']?.toString() ?? empPaycode,
            'emp_name': employeeData['emp_name']?.toString() ?? '',
            'loc_name': employeeData['loc_name']?.toString() ?? '',
            'dep_name': employeeData['dep_name']?.toString() ?? '',
            'reporting_manager_name': employeeData['reporting_manager']?['emp_name']?.toString() ?? '',
          };
        } else {
          debugPrint('⚠️ No employee field found in response');
          return null;
        }
      } else {
        debugPrint('❌ Employee API Error: ${response.statusCode}');
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to load employee data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in fetchEmployeeData: $e');
      rethrow;
    }
  }

  /// Safely parse a date string (plain "YYYY-MM-DD" or ISO with time/timezone)
  /// Returns a UTC DateTime so that .day/.month/.year always reflect the
  /// calendar date as sent by the server, regardless of device timezone.
  DateTime? _parseDateSafe(String raw) {
    try {
      // Strip timezone suffix (Z, +05:30, -05:00, etc.) and time component
      final withoutTz = raw
          .replaceAll(RegExp(r'[Zz]$'), '')
          .replaceAll(RegExp(r'[+-]\d{2}:\d{2}$'), '');
      final datePart = withoutTz.split('T')[0].split(' ')[0]; // "YYYY-MM-DD"
      final parts = datePart.split('-');
      if (parts.length == 3) {
        return DateTime.utc(
          int.parse(parts[0]), // year
          int.parse(parts[1]), // month
          int.parse(parts[2]), // day
        );
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ _parseDateSafe failed for "$raw": $e');
      return null;
    }
  }

  /// Cancel a miss punch application
  Future<bool> cancelMissPunchApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling miss punch application with ID: $applicationId');
      
      // Prepare form data for cancellation
      final formData = {
        'cancel_application': 'Cancel',
        'application_id': applicationId,
      };
      
      debugPrint('📤 Cancel form data: $formData');
      
      // Make authenticated form request for cancellation
      final response = await _authService.authenticatedFormRequest(
        endpoint: _missPunchEndpoint,
        formData: formData,
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      // Handle successful responses (200, 201) and redirects (302, 301)
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Check if the response indicates success
          if (responseData['success'] == true || 
              responseData['status'] == 'success' ||
              responseData['message']?.toString().toLowerCase().contains('success') == true ||
              responseData['message']?.toString().toLowerCase().contains('cancel') == true) {
            debugPrint('✅ Miss punch application cancelled successfully');
            return true;
          } else {
            debugPrint('⚠️ API returned success status but with error message: ${responseData['message']}');
            return false;
          }
        } catch (e) {
          // If response is not JSON, assume success based on status code
          debugPrint('✅ Miss punch application cancelled successfully (non-JSON response)');
          return true;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        debugPrint('🔄 Received redirect response (${response.statusCode})');
        final location = response.headers['location'];
        debugPrint('🔄 Redirect location: $location');
        
        // Check for Django messages in cookies to determine if it's success or error
        final setCookie = response.headers['set-cookie'];
        if (setCookie != null && setCookie.contains('messages=')) {
          debugPrint('📨 Server sent a message in redirect');
          
          // Try to decode the message to check if it's a success or error
          final cookieValue = setCookie.toLowerCase();
          
          if (cookieValue.contains('success') || 
              cookieValue.contains('cancel') || 
              cookieValue.contains('cancelled') ||
              cookieValue.contains('successfully')) {
            debugPrint('✅ Success message detected in redirect');
            return true;
          } else if (cookieValue.contains('error') || 
                     cookieValue.contains('failed') || 
                     cookieValue.contains('invalid')) {
            debugPrint('❌ Error message detected in redirect');
            return false;
          } else {
            debugPrint('⚠️ Unknown message type in redirect, assuming success');
            return true;
          }
        }
        
        // If no messages, then it's a successful redirect
        debugPrint('✅ Form submitted successfully (redirect without error messages)');
        return true;
      } else if (response.statusCode == 403) {
        debugPrint('❌ Authentication failed');
        throw Exception('Authentication failed. Please login again.');
      } else {
        debugPrint('❌ Cancel API Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error cancelling miss punch application: $e');
      return false;
    }
  }
}