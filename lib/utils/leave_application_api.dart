import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'dummy_data_service.dart';

class LeaveApplicationApiService {
  static const String _leaveApplicationEndpoint = 'https://delton.intellisync.in:11004/ess/leave-application/';
  
  final AuthService _authService = AuthService();
  
  /// Fetch leave applications from API
  Future<List<Map<String, dynamic>>> fetchLeaveApplications() async {
    try {
      debugPrint('🔄 Fetching leave applications from API...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy leave applications');
        return DummyDataService.getDummyLeaveApplications();
      }
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Construct the API endpoint with parameters
      // Try adding additional parameters to fetch all applications
      final endpoint = '$_leaveApplicationEndpoint?json=true&emp_paycode=$empPaycode&all=true&limit=100';
      debugPrint('🔗 API Endpoint: $endpoint');
      
      // Make authenticated request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Full Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Leave applications fetched successfully');
        
        // Parse the response data - the leave applications are in 'leave_list'
        if (responseData['leave_list'] != null) {
          final List<dynamic> dataList = responseData['leave_list'];
          debugPrint('📊 Found ${dataList.length} leave applications in response');
          
          // Convert to List<Map<String, dynamic>>
          final List<Map<String, dynamic>> applications = dataList.map((item) {
            // Use updated_by_name directly from the API response
            final approverName = item['updated_by_name']?.toString() ?? '';
            return {
              'id': item['id']?.toString() ?? '',
              'applicationType': item['application_type']?.toString() ?? 'Leave',
              'leaveType': item['leave_type']?.toString() ?? '',
              'fromDate': _formatDate(item['from_date']?.toString()),
              'toDate': _formatDate(item['till_date']?.toString()), // Fixed: till_date not to_date
              'dayPart': item['day_part']?.toString() ?? '',
              'dayCount': item['day_count']?.toString() ?? '',
              'applicationStatus': item['status']?.toString() ?? '', // Fixed: status not application_status
              'reason': item['reason']?.toString() ?? '',
              'appliedOn': _formatDate(item['applied_on']?.toString()),
              'approvedRejectedOn': _formatDate(item['approved_on']?.toString()), // Fixed: approved_on
              'cancelledOn': _formatDate(item['cancelled_on']?.toString()),
              'approvedRejectedBy': approverName,
              'remarks': item['remarks']?.toString() ?? '',
              'attachment': item['attachment']?.toString() ?? '',
            };
          }).toList();
          
          debugPrint('📋 Parsed ${applications.length} leave applications');
          return applications;
        } else {
          debugPrint('⚠️ No leave application data found in response - leave_list is empty or null');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch leave applications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching leave applications: $e');
      rethrow;
    }
  }
  
  /// Initialize session for new leave application (call when "Add New" is clicked)
  Future<bool> initializeSession() async {
    try {
      debugPrint('🔄 Initializing session for new leave application...');
      
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

  /// Submit a new leave application
  Future<bool> submitLeaveApplication({
    required String fromDate,
    required String tillDate,
    required String dayPart,
    required String address,
    required String phone,
    required String leaveType,
    required String reason,
    required String department,
    String? attachment, // Optional attachment file path
  }) async {
    try {
      debugPrint('🔄 Submitting leave application...');
      
      // Ensure we have a valid session before submitting
      final storedCsrfToken = await _authService.getStoredCsrfToken();
      if (storedCsrfToken == null || storedCsrfToken.isEmpty) {
        debugPrint('⚠️ No session found, initializing fresh session...');
        final sessionReady = await initializeSession();
        if (!sessionReady) {
          throw Exception('Failed to initialize session. Please try again.');
        }
      }
      
      debugPrint('📋 Input parameters:');
      debugPrint('   - fromDate: $fromDate');
      debugPrint('   - tillDate: $tillDate');
      debugPrint('   - dayPart: $dayPart');
      debugPrint('   - address: $address');
      debugPrint('   - phone: $phone');
      debugPrint('   - leaveType: $leaveType');
      debugPrint('   - reason: $reason');
      debugPrint('   - department: $department');
      debugPrint('   - attachment: $attachment');
      
      // Prepare request body with ONLY the exact field names that server expects
      final requestBody = {
        'from_date': fromDate,        // from_date = request.POST.get("from_date")
        'till_date': tillDate,        // till_date = request.POST.get("till_date")
        'day_part': dayPart,          // day_part = request.POST.get("day_part")
        'address': address,           // address = request.POST.get("address")
        'phone': phone,               // phone = request.POST.get("phone")
        'leave_type': leaveType,      // leave_type = request.POST.get("leave_type")
        'reason': reason,             // reason = request.POST.get("reason")
        'department': department,     // department = request.POST.get("department")
        // Note: attachment = request.FILES.get("attachment") - file upload handled separately
        // Note: NOT sending emp_paycode, applied_date, application_type, status as server doesn't expect them
      };
      
      debugPrint('📤 Final payload being sent to server:');
      debugPrint('   $requestBody');
      
      http.Response response;
      
      // Always use multipart form data (even without attachment) as server expects this format
      response = await _submitWithAttachment(requestBody, attachment);
      
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
          debugPrint('✅ Leave application submitted successfully');
          debugPrint('📋 Submit response: $responseData');
          
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
          debugPrint('✅ Leave application submitted successfully (non-JSON response)');
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
          // Django success messages typically contain words like "success", "saved", "submitted"
          // Error messages typically contain words like "error", "failed", "invalid"
          final cookieValue = setCookie.toLowerCase();
          
          if (cookieValue.contains('success') || 
              cookieValue.contains('saved') || 
              cookieValue.contains('submitted') ||
              cookieValue.contains('created') ||
              cookieValue.contains('successfully')) {
            debugPrint('✅ Success message detected in redirect');
            return true;
          } else if (cookieValue.contains('error') || 
                     cookieValue.contains('failed') || 
                     cookieValue.contains('invalid') ||
                     cookieValue.contains('required')) {
            debugPrint('❌ Error message detected in redirect');
            throw Exception('Leave application validation failed. Please check your input and try again.');
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
        debugPrint('❌ Submit API Error: ${response.statusCode}');
        throw Exception('Failed to submit leave application. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Network error in submitLeaveApplication: $e');
      rethrow;
    }
  }

  /// Submit leave application with file attachment using multipart form data
  Future<http.Response> _submitWithAttachment(Map<String, String> requestBody, String? filePath) async {
    try {
      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('📎 Submitting with attachment: $filePath');
      } else {
        debugPrint('📝 Submitting without attachment (using multipart form)');
      }
      
      // Get fresh CSRF token (already fetched in submitLeaveApplication)
      final csrfToken = await _authService.getStoredCsrfToken();
      final cookies = await _authService.getSessionCookies();
      
      // Create multipart request
      final uri = Uri.parse(_leaveApplicationEndpoint);
      final request = http.MultipartRequest('POST', uri);
      
      // Add headers including Origin and Referer for Django CSRF validation
      request.headers.addAll({
        'Cookie': cookies,
        'User-Agent': 'AttendanceApp/1.0',
        'Origin': _authService.baseUrl,      // Required for Django CSRF
        'Referer': _authService.baseUrl,    // Required for Django CSRF
      });
      
      if (csrfToken != null && csrfToken.isNotEmpty) {
        request.headers['X-CSRFToken'] = csrfToken;
        request.headers['X-Csrftoken'] = csrfToken;  // Alternative case
        debugPrint('🔐 Added CSRF token to multipart request');
      }
      
      // Add CSRF token to form fields as well
      if (csrfToken != null && csrfToken.isNotEmpty) {
        requestBody['csrfmiddlewaretoken'] = csrfToken;
        debugPrint('🔐 Added CSRF token to form fields');
      }
      
      // Add form fields
      request.fields.addAll(requestBody);
      
      // Add file attachment only if provided
      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          final multipartFile = await http.MultipartFile.fromPath(
            'attachment', // This matches request.FILES.get("attachment")
            filePath,
          );
          request.files.add(multipartFile);
          debugPrint('📎 Added file attachment: ${multipartFile.filename} (${multipartFile.length} bytes)');
        } else {
          debugPrint('⚠️ Attachment file not found: $filePath');
        }
      } else {
        debugPrint('📝 No attachment to add');
      }
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📊 Multipart response status: ${response.statusCode}');
      return response;
      
    } catch (e) {
      debugPrint('❌ Error in multipart upload: $e');
      rethrow;
    }
  }
  
  /// Cancel a leave application
  Future<bool> cancelLeaveApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling leave application with ID: $applicationId');
      
      // Prepare form data for cancellation
      final formData = {
        'cancel_application': 'Cancel',
        'application_id': applicationId,
      };
      
      debugPrint('📤 Cancel form data: $formData');
      
      // Make authenticated form request for cancellation using form data
      final response = await _authService.authenticatedFormRequest(
        endpoint: _leaveApplicationEndpoint,
        formData: formData,
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');
      
      // Handle successful responses (200, 201) and redirects (302, 301)
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Check if the response indicates success
          if (responseData['success'] == true || 
              responseData['status'] == 'success' ||
              responseData['message']?.toString().toLowerCase().contains('success') == true ||
              responseData['message']?.toString().toLowerCase().contains('cancel') == true) {
            debugPrint('✅ Leave application cancelled successfully');
            return true;
          } else {
            debugPrint('⚠️ API returned success status but with error message: ${responseData['message']}');
            return false;
          }
        } catch (e) {
          // If response is not JSON, assume success based on status code
          debugPrint('✅ Leave application cancelled successfully (non-JSON response)');
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
      debugPrint('❌ Error cancelling leave application: $e');
      return false;
    }
  }
  
  /// Fetch employee data for form pre-filling
  Future<Map<String, dynamic>?> fetchEmployeeData() async {
    try {
      debugPrint('🔄 Fetching employee data for form pre-filling...');
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Try to get employee data from the JSON endpoint
      final jsonEndpoint = '$_leaveApplicationEndpoint?json=true&emp_paycode=$empPaycode';
      debugPrint('🔗 Employee data endpoint: $jsonEndpoint');
      
      final jsonResponse = await _authService.authenticatedRequest(
        endpoint: jsonEndpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Response status: ${jsonResponse.statusCode}');
      debugPrint('📄 Response body: ${jsonResponse.body}');
      
      if (jsonResponse.statusCode == 200) {
        final responseData = jsonDecode(jsonResponse.body);
        debugPrint('✅ Employee data fetched successfully');
        
        // Parse the employee data from the new API structure
        if (responseData['employee'] != null) {
          final employee = responseData['employee'];
          final reportingManager = employee['reporting_manager'];
          
          return {
            'emp_code': employee['emp_paycode']?.toString() ?? empPaycode,
            'emp_name': employee['emp_name']?.toString() ?? '',
            'loc_name': employee['loc_name']?.toString() ?? 'HO',
            'dep_name': employee['dep_name']?.toString() ?? '',
            'reporting_manager_name': reportingManager?['emp_name']?.toString() ?? '',
            'reporting_manager_paycode': reportingManager?['emp_paycode']?.toString() ?? '',
          };
        }
      }
      
      // If JSON endpoint didn't work, try to get employee data from the HTML form page
      const endpoint = _leaveApplicationEndpoint;
      debugPrint('🔗 Fallback to HTML endpoint: $endpoint');
      
      // Make authenticated request to get the form page
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 HTML Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        debugPrint('✅ HTML Form page fetched successfully');
        
        // Try to extract employee data from the HTML form
        Map<String, String> extractedData = {};
        
        // Extract employee code from form fields or use paycode
        extractedData['emp_code'] = empPaycode;
        
        // Try to extract employee name from HTML
        final nameMatch = RegExp(r'name=["\x27]emp_name["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]').firstMatch(responseBody);
        if (nameMatch != null) {
          extractedData['emp_name'] = nameMatch.group(1) ?? '';
        }
        
        // Try to extract department from HTML
        final deptMatch = RegExp(r'name=["\x27]department["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]').firstMatch(responseBody);
        if (deptMatch != null) {
          extractedData['dep_name'] = deptMatch.group(1) ?? '';
        }
        
        // Try to extract location from HTML
        final locMatch = RegExp(r'name=["\x27]location["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]').firstMatch(responseBody);
        if (locMatch != null) {
          extractedData['loc_name'] = locMatch.group(1) ?? 'HO';
        }
        
        // If we found some data, return it
        if (extractedData.isNotEmpty) {
          return {
            'emp_code': extractedData['emp_code'] ?? empPaycode,
            'emp_name': extractedData['emp_name'] ?? '',
            'loc_name': extractedData['loc_name'] ?? 'HO',
            'dep_name': extractedData['dep_name'] ?? '',
            'reporting_manager_name': '', // Empty default value
          };
        }
      }
      
      // Try to get data from auth service profile as fallback
      try {
        final profileData = await _authService.getEmployeeProfile();
        if (profileData != null) {
          return {
            'emp_code': profileData['emp_code'] ?? empPaycode,
            'emp_name': profileData['emp_name'] ?? '',
            'loc_name': 'HO', // Default location
            'dep_name': '', // Will need to be filled manually
            'reporting_manager_name': '', // Empty default manager
          };
        }
      } catch (e) {
        debugPrint('⚠️ Auth service profile failed: $e');
      }
      
      // Return default data with employee paycode
      debugPrint('⚠️ Using default employee data');
      return {
        'emp_code': empPaycode,
        'emp_name': '',
        'loc_name': 'HO',
        'dep_name': '',
        'reporting_manager_name': '',
      };
      
    } catch (e) {
      debugPrint('❌ Error fetching employee data: $e');
      
      // Try to get at least the employee paycode
      try {
        final empPaycode = await _authService.getEmployeePaycode();
        return {
          'emp_code': empPaycode ?? '',
          'emp_name': '',
          'loc_name': 'HO',
          'dep_name': '',
          'reporting_manager_name': '',
        };
      } catch (e) {
        debugPrint('❌ Error getting employee paycode: $e');
        return null;
      }
    }
  }
  
  /// Format date string to DD-MM-YYYY format
  /// Converts UTC dates to local timezone before formatting
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    
    try {
      // Parse the date string (which is in UTC from the server)
      final utcDate = DateTime.parse(dateStr);
      
      // Convert UTC to local time
      final localDate = utcDate.toLocal();
      
      // Format as DD-MM-YYYY
      final day = localDate.day.toString().padLeft(2, '0');
      final month = localDate.month.toString().padLeft(2, '0');
      final year = localDate.year.toString();
      
      debugPrint('📅 Date conversion: UTC=$dateStr -> Local=${localDate.toString()} -> Formatted=$day-$month-$year');
      
      return '$day-$month-$year';
    } catch (e) {
      debugPrint('❌ Error parsing date: $dateStr - $e');
      return dateStr;
    }
  }
}