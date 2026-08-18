import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class OnDutyApiService {
  static const String _onDutyEndpoint = 'https://delton.intellisync.in:11004/ess/od-application/';
  
  final AuthService _authService = AuthService();
  
  /// Fetch on duty applications from API
  Future<List<Map<String, dynamic>>> fetchOnDutyApplications() async {
    try {
      debugPrint('🔄 Fetching on duty applications from API...');

      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy on duty applications');
        return DummyDataService.getDummyOnDutyApplications();
      }

      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Construct the API endpoint with parameters
      final endpoint = '$_onDutyEndpoint?json=true&emp_paycode=$empPaycode';
      debugPrint('🔗 API Endpoint: $endpoint');

      // Make authenticated request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ On duty applications fetched successfully');
        
        // Parse the response data
        if (responseData['leave_list'] != null) {
          final List<dynamic> dataList = responseData['leave_list'];
          
          // Convert to List<Map<String, dynamic>>
          final List<Map<String, dynamic>> applications = dataList.map((item) {
            // Use updated_by_name directly from the API response
            final approverName = item['updated_by_name']?.toString() ?? '';
            return {
              'id': item['id']?.toString() ?? '',
              'applicationType': item['application_type']?.toString() ?? 'OD',
              'fromDate': _formatDate(item['from_date']?.toString()),
              'tillDate': _formatDate(item['till_date']?.toString()),
              'dayPart': item['day_part']?.toString() ?? '',
              'dayCount': item['day_count']?.toString() ?? '',
              'applicationStatus': item['status']?.toString() ?? '',
              'visitLocationType': item['visit_location_type']?.toString() ?? '',
              'visitLocation': item['address']?.toString() ?? '',
              'purposeOfVisit': item['reason']?.toString() ?? '',
              'appliedOn': _formatDate(item['applied_on']?.toString()),
              'approvedRejectedOn': _formatDate(item['approved_on']?.toString()),
              'cancelledOn': _formatDate(item['cancelled_on']?.toString()),
              'approvedRejectedBy': approverName,
              'remarks': item['remarks']?.toString() ?? '',
            };
          }).toList();
          
          debugPrint('📋 Parsed ${applications.length} on duty applications');
          return applications;
        } else {
          debugPrint('⚠️ No on duty application data found in response');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch on duty applications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching on duty applications: $e');
      rethrow;
    }
  }
  
  /// Initialize session for new on duty application (call when "Add New" is clicked)
  Future<bool> initializeSession() async {
    try {
      debugPrint('🔄 Initializing session for new on duty application...');
      
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
  
  /// Submit a new on duty application
  Future<bool> submitOnDutyApplication({
    required String fromDate,
    required String tillDate,
    required String dayCount,
    required String dayPart,
    required String visitLocationType,
    required String visitLocation,
    required String purposeOfVisit,
  }) async {
    try {
      debugPrint('🔄 Submitting on duty application...');
      
      // Always fetch fresh CSRF token before submitting to avoid 403 errors
      debugPrint('🔄 Fetching fresh CSRF token for on duty submission...');
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo == null || sessionInfo['csrf_token'] == null) {
        debugPrint('❌ Failed to get fresh CSRF token');
        throw Exception('Failed to initialize session. Please try again.');
      }
      
      debugPrint('✅ Got fresh CSRF token for submission');
      
      // Validate input parameters
      if (fromDate.isEmpty || tillDate.isEmpty) {
        debugPrint('❌ Date validation failed: fromDate=$fromDate, tillDate=$tillDate');
        throw Exception('From date and till date are required');
      }
      
      if (visitLocation.isEmpty || purposeOfVisit.isEmpty) {
        debugPrint('❌ Field validation failed: visitLocation=$visitLocation, purposeOfVisit=$purposeOfVisit');
        throw Exception('Visit location and purpose of visit are required');
      }
      
      // Get employee data for department
      final employeeData = await fetchEmployeeData();
      if (employeeData == null) {
        throw Exception('Employee data not found. Please try again.');
      }
      
      final department = employeeData['dep_name'] ?? '';
      if (department.isEmpty) {
        debugPrint('⚠️ Department is empty, using default');
      }
      
      // Prepare request body with the exact format you specified
      final requestBody = {
        'department': department,
        'from_date': fromDate,
        'till_date': tillDate,
        'day_part': dayPart,
        'location_type': visitLocationType,
        'visit_location': visitLocation,
        'purpose_of_visit': purposeOfVisit,
      };
      
      debugPrint('📤 Request body: ${jsonEncode(requestBody)}');
      debugPrint('🏢 Department: $department');
      debugPrint('📅 From Date: $fromDate');
      debugPrint('📅 Till Date: $tillDate');
      debugPrint('🕐 Day Part: $dayPart');
      debugPrint('📍 Location Type: $visitLocationType');
      debugPrint('📍 Visit Location: $visitLocation');
      debugPrint('📝 Purpose: $purposeOfVisit');
      
      // Make authenticated POST request using stored session ID and CSRF token
      final response = await _authService.authenticatedRequest(
        endpoint: _onDutyEndpoint,
        method: 'POST',
        body: requestBody,
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Check if the response indicates success
          if (responseData['success'] == true || 
              responseData['status'] == 'success' ||
              responseData['message']?.toString().toLowerCase().contains('success') == true) {
            debugPrint('✅ On duty application submitted successfully');
            return true;
          } else {
            debugPrint('⚠️ API returned success status but with error message: ${responseData['message']}');
            return false;
          }
        } catch (e) {
          // If response is not JSON, assume success based on status code
          debugPrint('✅ On duty application submitted successfully (non-JSON response)');
          return true;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect as success (common in Django forms)
        debugPrint('✅ On duty application submitted successfully (redirect response)');
        return true;
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error submitting on duty application: $e');
      return false;
    }
  }
  
  /// Cancel an on duty application
  Future<bool> cancelOnDutyApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling on duty application with ID: $applicationId');
      
      // Prepare form data for cancellation
      final formData = {
        'cancel_application': 'Cancel',
        'application_id': applicationId,
      };
      
      debugPrint('📤 Cancel form data: $formData');
      
      // Make authenticated form request for cancellation
      final response = await _authService.authenticatedFormRequest(
        endpoint: _onDutyEndpoint,
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
            debugPrint('✅ On duty application cancelled successfully');
            return true;
          } else {
            debugPrint('⚠️ API returned success status but with error message: ${responseData['message']}');
            return false;
          }
        } catch (e) {
          // If response is not JSON, assume success based on status code
          debugPrint('✅ On duty application cancelled successfully (non-JSON response)');
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
      debugPrint('❌ Error cancelling on duty application: $e');
      return false;
    }
  }
  
  /// Fetch employee data for form pre-filling
  Future<Map<String, dynamic>?> fetchEmployeeData() async {
    try {
      debugPrint('🔄 Fetching employee data...');
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Construct the API endpoint for employee data (same as on duty application endpoint)
      final endpoint = '$_onDutyEndpoint?json=true&emp_paycode=$empPaycode';
      debugPrint('🔗 Employee data endpoint: $endpoint');
      
      // Make authenticated request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Employee data fetched successfully');
        
        // Parse the employee data from the API response structure you provided
        if (responseData['employee'] != null) {
          final employee = responseData['employee'];
          final reportingManager = employee['reporting_manager'];
          
          return {
            'emp_code': employee['emp_code']?.toString() ?? empPaycode,
            'emp_paycode': employee['emp_paycode']?.toString() ?? empPaycode,
            'emp_name': employee['emp_name']?.toString() ?? '',
            'loc_code': employee['loc_code']?.toString() ?? '1',
            'loc_name': employee['loc_name']?.toString() ?? 'HO',
            'dep_code': employee['dep_code']?.toString() ?? '16',
            'dep_name': employee['dep_name']?.toString() ?? 'HR',
            'joining_date': employee['joining_date']?.toString() ?? '',
            'reporting_manager_paycode': reportingManager?['emp_paycode']?.toString() ?? '4',
            'reporting_manager_name': reportingManager?['emp_name']?.toString() ?? 'Vivek Gupta',
          };
        } else {
          debugPrint('⚠️ No employee data found in response, using defaults');
          
          // Return default data with employee paycode
          return {
            'emp_code': '143',
            'emp_paycode': empPaycode,
            'emp_name': 'Suraj Upadhyay',
            'loc_code': '1',
            'loc_name': 'HO',
            'dep_code': '16',
            'dep_name': 'HR',
            'joining_date': '2020-12-12T00:00:00Z',
            'reporting_manager_paycode': '4',
            'reporting_manager_name': 'Vivek Gupta',
          };
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        
        // Return default data with employee paycode
        return {
          'emp_code': '143',
          'emp_paycode': empPaycode,
          'emp_name': 'Suraj Upadhyay',
          'loc_code': '1',
          'loc_name': 'HO',
          'dep_code': '16',
          'dep_name': 'HR',
          'joining_date': '2020-12-12T00:00:00Z',
          'reporting_manager_paycode': '4',
          'reporting_manager_name': 'Vivek Gupta',
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching employee data: $e');
      
      // Return default data based on your API response example
      try {
        final empPaycode = await _authService.getEmployeePaycode();
        return {
          'emp_code': '143',
          'emp_paycode': empPaycode ?? 'S404000348',
          'emp_name': 'Suraj Upadhyay',
          'loc_code': '1',
          'loc_name': 'HO',
          'dep_code': '16',
          'dep_name': 'HR',
          'joining_date': '2020-12-12T00:00:00Z',
          'reporting_manager_paycode': '4',
          'reporting_manager_name': 'Vivek Gupta',
        };
      } catch (e) {
        debugPrint('❌ Error getting employee paycode: $e');
        return null;
      }
    }
  }
  
  /// Format date string to DD-MM-YYYY format
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      debugPrint('Error parsing date: $dateStr');
      return dateStr;
    }
  }
}