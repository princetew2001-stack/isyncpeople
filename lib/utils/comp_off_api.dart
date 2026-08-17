import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class CompOffApiService {
  static const String _endpoint = 'https://delton.intellisync.in:11004/ess/comp-off-application/';

  final AuthService _authService = AuthService();

  // ─── Fetch list ────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchCompOffApplications() async {
    try {
      debugPrint('🔄 Fetching comp-off applications...');

      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }

      final endpoint = '$_endpoint?json=true&emp_paycode=$empPaycode';
      debugPrint('🔗 Endpoint: $endpoint');

      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Response status: ${response.statusCode}');
      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Comp-off data fetched successfully');
        debugPrint('📄 Response body: ${response.body}');

        // Try multiple possible keys for the list
        final List<dynamic> dataList = responseData['comoff_list'] ?? 
                                       responseData['compoff_list'] ?? 
                                       responseData['leave_list'] ?? 
                                       [];
        debugPrint('📋 Found ${dataList.length} comp-off applications');

        return dataList.map((item) {
          final compOffDate = _formatDate(item['from_date']?.toString());
          final workingDate = _formatDate(item['till_date']?.toString());
          
          debugPrint('📝 Mapping item ${item['id']}: from_date=${item['from_date']}, till_date=${item['till_date']}');
          debugPrint('   Formatted: compOffDate=$compOffDate, workingDate=$workingDate');
          
          return {
            'id': item['id']?.toString() ?? '',
            'applicationType': item['application_type']?.toString() ?? 'Comp-off',
            'compOffDate': compOffDate,
            'workingDate': workingDate,
            'dayPart': item['day_part']?.toString() ?? '',
            'dayCount': item['day_count']?.toString() ?? '',
            'applicationStatus': item['status']?.toString() ?? '',
            'reason': item['reason']?.toString() ?? '',
            'address': item['address']?.toString() ?? '',
            'mobileNumber': item['mobile_number']?.toString() ?? '',
            'appliedOn': _formatDate(item['applied_on']?.toString()),
            'approvedOn': _formatDate(item['approved_on']?.toString()),
            'rejectedOn': item['status']?.toString().toLowerCase() == 'rejected'
                ? _formatDate(item['approved_on']?.toString())
                : '',
            'cancelledOn': _formatDate(item['cancelled_on']?.toString()),
            'updatedBy': item['updated_by_name']?.toString() ?? '',
            'remarks': item['remarks']?.toString() ?? '',
          };
        }).toList();
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch comp-off applications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in fetchCompOffApplications: $e');
      rethrow;
    }
  }

  // ─── Fetch employee data (for form pre-fill) ───────────────────────────────
  Future<Map<String, dynamic>?> fetchEmployeeData() async {
    try {
      debugPrint('🔄 Fetching employee data for comp-off form...');

      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }

      final endpoint = '$_endpoint?json=true&emp_paycode=$empPaycode';

      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['employee'] != null) {
          final emp = responseData['employee'];
          final rm  = emp['reporting_manager'];

          return {
            'emp_code':                emp['emp_code']?.toString()     ?? '',
            'emp_paycode':             emp['emp_paycode']?.toString()   ?? '',
            'emp_name':                emp['emp_name']?.toString()      ?? '',
            'loc_code':                emp['loc_code']?.toString()      ?? '',
            'loc_name':                emp['loc_name']?.toString()      ?? '',
            'dep_code':                emp['dep_code']?.toString()      ?? '',
            'dep_name':                emp['dep_name']?.toString()      ?? '',
            'joining_date':            emp['joining_date']?.toString()  ?? '',
            'reporting_manager_paycode': rm?['emp_paycode']?.toString() ?? '',
            'reporting_manager_name':    rm?['emp_name']?.toString()    ?? '',
          };
        }

        debugPrint('⚠️ No employee field in response');
        return null;
      } else {
        debugPrint('❌ Employee data API Error: ${response.statusCode}');
        throw Exception('Failed to fetch employee data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in fetchEmployeeData: $e');
      rethrow;
    }
  }

  // ─── Initialize session (CSRF) ─────────────────────────────────────────────
  Future<bool> initializeSession() async {
    try {
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo != null) {
        debugPrint('✅ Comp-off session initialized');
        return true;
      }
      debugPrint('❌ Failed to initialize comp-off session');
      return false;
    } catch (e) {
      debugPrint('❌ Error initializing session: $e');
      return false;
    }
  }

  // ─── Submit new application ────────────────────────────────────────────────
  Future<bool> submitCompOffApplication({
    required String compOffDate,
    required String workingDate,
    required String dayPart,
    required String address,
    required String mobileNumber,
    required String reason,
    required String department,
  }) async {
    try {
      debugPrint('🔄 Submitting comp-off application...');

      // Always fetch fresh CSRF token before submitting to avoid 403 errors
      debugPrint('🔄 Fetching fresh CSRF token for comp-off submission...');
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo == null || sessionInfo['csrf_token'] == null) {
        debugPrint('❌ Failed to get fresh CSRF token');
        throw Exception('Failed to initialize session. Please try again.');
      }

      debugPrint('✅ Got fresh CSRF token for submission');

      // Validate input parameters
      if (compOffDate.isEmpty || workingDate.isEmpty) {
        debugPrint('❌ Date validation failed: compOffDate=$compOffDate, workingDate=$workingDate');
        throw Exception('Comp-off date and working date are required');
      }

      if (address.isEmpty || mobileNumber.isEmpty || reason.isEmpty) {
        debugPrint('❌ Field validation failed: address=$address, phone=$mobileNumber, reason=$reason');
        throw Exception('Address, mobile number, and reason are required');
      }

      // Prepare request body with the exact format specified for comp-off
      // Note: Comp-off uses different field names than leave application
      final formData = {
        'leave_from':  compOffDate,    // Comp-off date (different from leave application)
        'working_day': workingDate,    // Working date (different from leave application)
        'day_part':    dayPart,        // FD or HD
        'address':     address,        // Address during day period
        'phone':       mobileNumber,   // Mobile number
        'reason':      reason,         // Reason for leave
        'department':  department,     // Department
      };

      debugPrint('📤 Request body: $formData');
      debugPrint('🏢 Department: $department');
      debugPrint('📅 Comp-off Date (leave_from): $compOffDate');
      debugPrint('📅 Working Date (working_day): $workingDate');
      debugPrint('🕐 Day Part: $dayPart');
      debugPrint('📍 Address: $address');
      debugPrint('📱 Phone: $mobileNumber');
      debugPrint('📝 Reason: $reason');

      // Make authenticated POST request using form data (like leave application)
      final response = await _authService.authenticatedFormRequest(
        endpoint: _endpoint,
        formData: formData,
      );

      debugPrint('📊 Submit response: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          
          // Check if the response indicates success
          if (data['success'] == true || 
              data['status'] == 'success' ||
              data['message']?.toString().toLowerCase().contains('success') == true) {
            debugPrint('✅ Comp-off application submitted successfully');
            return true;
          } else {
            debugPrint('⚠️ API returned success status but with error message: ${data['message']}');
            return false;
          }
        } catch (_) {
          // non-JSON 200 → assume success
          debugPrint('✅ Comp-off application submitted successfully (non-JSON response)');
          return true;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect as success (common in Django forms)
        debugPrint('✅ Comp-off application submitted successfully (redirect response)');
        return true;
      } else {
        debugPrint('❌ Submit error: ${response.statusCode}');
        throw Exception('Failed to submit comp-off application: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in submitCompOffApplication: $e');
      rethrow;
    }
  }

  // ─── Cancel application ────────────────────────────────────────────────────
  Future<bool> cancelCompOffApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling comp-off application: $applicationId');

      final response = await _authService.authenticatedFormRequest(
        endpoint: _endpoint,
        formData: {
          'cancel_application': 'Cancel',
          'application_id':     applicationId,
        },
      );

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          return data['success'] == true ||
              data['status'] == 'success' ||
              data['message']?.toString().toLowerCase().contains('cancel') == true;
        } catch (_) {
          return true;
        }
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        return true;
      } else {
        debugPrint('❌ Cancel error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error in cancelCompOffApplication: $e');
      return false;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
