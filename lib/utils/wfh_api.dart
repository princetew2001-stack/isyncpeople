import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'dummy_data_service.dart';

class WFHApiService {
  static const String _wfhEndpoint =
      'https://delton.intellisync.in:11004/ess/wfh-application/';

  final AuthService _authService = AuthService();

  // ─── Fetch list ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWFHApplications() async {
    try {
      debugPrint('🔗 Starting WFH API call...');

      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user — returning empty WFH list');
        return [];
      }

      const endpoint =
          'https://delton.intellisync.in:11004/ess/wfh-application/?json=true';

      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ WFH data fetched');

        String fmt(String? iso) {
          if (iso == null || iso.isEmpty) return '--';
          try {
            final d = DateTime.parse(iso).toLocal();
            return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
          } catch (_) {
            return '--';
          }
        }

        // API response: { "data": { "leave_data": [...] } }
        final dynamic dataBlock = responseData['data'] ?? responseData;
        final List<dynamic>? list =
            (dataBlock is Map) ? (dataBlock['leave_data'] ?? dataBlock['leave_list']) : null;

        if (list != null) {
          debugPrint('📊 Found ${list.length} WFH records');
          // null or empty value -> '--'
          String v(dynamic val) =>
              (val == null || val.toString().trim().isEmpty) ? '--' : val.toString();

          return list.map((item) => {
                'id'               : v(item['id']),
                'applicationType'  : v(item['application_type']),
                'from'             : fmt(item['from_date']?.toString()),
                'till'             : fmt(item['till_date']?.toString()),
                'dayPart'          : v(item['day_part']),
                'dayCount'         : v(item['day_count']),
                'applicationStatus': v(item['status']),
                // wfh_reason is the actual reason field in this API
                'reason'           : v(item['wfh_reason'] ?? item['reason']),
                'appliedOn'        : fmt(item['applied_on']?.toString()),
                'approvedOn'       : fmt(item['approved_on']?.toString()),
                'attachment'       : v(item['attachment']),
                'remarks'          : v(item['remarks']),
                'reportingManager' : v(item['reporting_manager']),
              }).toList();
        }
        return [];
      } else {
        throw Exception('Failed to load WFH data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ fetchWFHApplications error: $e');
      rethrow;
    }
  }

  // ─── Employee data ───────────────────────────────────────────────────────────

  /// Get employee basic info from local SharedPreferences (login data fallback)
  Future<Map<String, dynamic>?> getLocalEmployeeProfile() async {
    return await _authService.getEmployeeProfile();
  }

  /// Initialize session before opening Add New form
  Future<bool> initializeSession() async {
    try {
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo != null) {
        debugPrint('✅ WFH session initialized');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error initializing WFH session: $e');
      return false;
    }
  }

  /// Fetch employee data for WFH form pre-fill — reuses miss punch endpoint
  Future<Map<String, dynamic>?> fetchEmployeeData() async {
    try {
      debugPrint('🔗 Fetching employee data for WFH form...');

      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee ID not found. Please login again.');
      }

      // Reuse miss punch endpoint — returns employee object in same structure
      const endpoint =
          'https://delton.intellisync.in:11004/ess/miss-punch-application/?json=true';

      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['employee'] != null) {
          final emp = responseData['employee'];
          return {
            'emp_code': emp['emp_code']?.toString() ?? '',
            'emp_name': emp['emp_name']?.toString() ?? '',
            'loc_name': emp['loc_name']?.toString() ?? '',
            'dep_name': emp['dep_name']?.toString() ?? '',
            'reporting_manager_name':
                emp['reporting_manager']?['emp_name']?.toString() ?? '',
          };
        }
        return null;
      } else {
        throw Exception(
            'Failed to load employee data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ fetchEmployeeData error: $e');
      rethrow;
    }
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  /// Submit WFH application — same pattern as leave application (multipart POST)
  /// Fields sent: application_type, leave_from, leave_till, day_part, reason, reporting_manager
  Future<bool> submitWFHApplication({
    required String fromDate,
    required String tillDate,
    required String dayPart,
    required String reason,
    required String department,
    String reportingManager = '',
  }) async {
    try {
      debugPrint('🔄 Submitting WFH application...');

      // Always fetch a fresh CSRF token before submitting — stale tokens cause 403
      debugPrint('🔄 Fetching fresh CSRF token before WFH submit...');
      final sessionInfo = await _authService.getSessionInfo();
      if (sessionInfo == null) {
        debugPrint('⚠️ Could not refresh session, falling back to stored token');
        final storedCsrf = await _authService.getStoredCsrfToken();
        if (storedCsrf == null || storedCsrf.isEmpty) {
          throw Exception('Failed to initialize session. Please try again.');
        }
      }

      debugPrint('📋 WFH payload:');
      debugPrint('   application_type  : WFH');
      debugPrint('   leave_from        : $fromDate');
      debugPrint('   leave_till        : $tillDate');
      debugPrint('   day_part          : $dayPart');
      debugPrint('   reason            : $reason');
      debugPrint('   department        : $department');
      debugPrint('   reporting_manager : $reportingManager');

      // Build form fields — exact field names the server expects
      final fields = <String, String>{
        'application_type'  : 'WFH',
        'leave_from'        : fromDate,
        'leave_till'        : tillDate,
        'day_part'          : dayPart,
        'reason'            : reason,
        'department'        : department,
        if (reportingManager.isNotEmpty)
          'reporting_manager': reportingManager,
      };

      final response = await _submitMultipart(fields);

      debugPrint('📊 Submit status: ${response.statusCode}');
      debugPrint('📋 Submit headers: ${response.headers}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 500) {
        debugPrint('❌ Server 500 — body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      }

      // 200 / 201
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          return data['success'] == true || data['status'] == 'success';
        } catch (_) {
          return true; // non-JSON 200 → assume success
        }
      }

      // 301 / 302 redirect (Django standard after form POST)
      if (response.statusCode == 302 || response.statusCode == 301) {
        debugPrint('🔄 Redirect: ${response.headers['location']}');
        final cookie = response.headers['set-cookie']?.toLowerCase() ?? '';
        if (cookie.contains('messages=')) {
          if (cookie.contains('error') ||
              cookie.contains('failed') ||
              cookie.contains('invalid')) {
            throw Exception(
                'WFH application validation failed. Please check your input.');
          }
        }
        return true; // redirect without error = success
      }

      if (response.statusCode == 403) {
        throw Exception('Authentication failed. Please login again.');
      }

      throw Exception(
          'Failed to submit WFH application (${response.statusCode}).');
    } catch (e) {
      debugPrint('❌ submitWFHApplication error: $e');
      rethrow;
    }
  }

  /// Multipart POST — same approach as leave application's _submitWithAttachment
  Future<http.Response> _submitMultipart(Map<String, String> fields) async {
    try {
      final csrfToken = await _authService.getStoredCsrfToken();
      final cookies = await _authService.getSessionCookies();

      final uri = Uri.parse(_wfhEndpoint);
      final request = http.MultipartRequest('POST', uri);

      // Headers — same as leave application
      request.headers.addAll({
        'Cookie': cookies,
        'User-Agent': 'AttendanceApp/1.0',
        'Origin': _authService.baseUrl,
        'Referer': _authService.baseUrl,
      });

      if (csrfToken != null && csrfToken.isNotEmpty) {
        request.headers['X-CSRFToken'] = csrfToken;
        request.headers['X-Csrftoken'] = csrfToken;
        fields['csrfmiddlewaretoken'] = csrfToken;
        debugPrint('🔐 CSRF token added to WFH request');
      }

      request.fields.addAll(fields);

      debugPrint('📤 WFH multipart fields: ${request.fields}');

      final streamed = await request.send();
      return await http.Response.fromStream(streamed);
    } catch (e) {
      debugPrint('❌ _submitMultipart error: $e');
      rethrow;
    }
  }

  // ─── Cancel ──────────────────────────────────────────────────────────────────

  Future<bool> cancelWFHApplication(String applicationId) async {
    try {
      debugPrint('🔄 Cancelling WFH application ID: $applicationId');

      final formData = {
        'cancel_application': 'Cancel',
        'application_id': applicationId,
      };

      final response = await _authService.authenticatedFormRequest(
        endpoint: _wfhEndpoint,
        formData: formData,
      );

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          return data['success'] == true ||
              data['status'] == 'success' ||
              (data['message']?.toString().toLowerCase().contains('cancel') ?? false);
        } catch (_) {
          return true;
        }
      }
      if (response.statusCode == 302 || response.statusCode == 301) return true;
      return false;
    } catch (e) {
      debugPrint('❌ cancelWFHApplication error: $e');
      return false;
    }
  }
}
