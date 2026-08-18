import 'dart:convert';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class EmployeeApiService {
  final AuthService _authService = AuthService();

  /// Fetch employee data from the API with optional filters
  Future<List<Map<String, dynamic>>> fetchEmployees({
    String? fromDate,
    String? toDate,
    String? name,
    String? status,
    String? unit,
    String? type,
  }) async {
    try {
      debugPrint('🔗 Starting employee API call with filters...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy employee/visitor data');
        return DummyDataService.getDummyEmployeeVisitorData();
      }
      
      // Get employee paycode
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        debugPrint('❌ No employee paycode found');
        throw Exception('Employee ID not found. Please login again.');
      }
      
      debugPrint('📱 Employee paycode: $empPaycode');
      
      // Build query parameters
      final Map<String, String> queryParams = {'json': '1'};
      
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from_date'] = fromDate;
        debugPrint('📅 From Date filter: $fromDate');
      }
      
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to_date'] = toDate;
        debugPrint('📅 To Date filter: $toDate');
      }
      
      if (name != null && name.isNotEmpty) {
        queryParams['name'] = name;
        debugPrint('👤 Name filter: $name');
      }
      
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
        debugPrint('📋 Status filter: $status');
      }
      
      if (unit != null && unit.isNotEmpty && unit != 'All') {
        queryParams['unit'] = unit;
        debugPrint('🏢 Unit filter: $unit');
      }
      
      if (type != null && type.isNotEmpty && type != 'All') {
        queryParams['type'] = type;
        debugPrint('🏷️ Type filter: $type');
      }
      
      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      // Construct the API endpoint with filters
      final endpoint = '/visitors/employee-screen/?$queryString';
      debugPrint('🔗 Fetching employee data from: $endpoint');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 API Response status: ${response.statusCode}');
      debugPrint('📄 API Response body: ${response.body}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Employee data fetched successfully');
        debugPrint('📋 Response data structure: ${responseData.keys}');
        
        // Parse the response data based on your API structure
        if (responseData['status'] == 'success' && responseData['data'] != null) {
          final List<dynamic> dataList = responseData['data'];
          debugPrint('📊 Found ${dataList.length} employees');
          
          final List<Map<String, dynamic>> employeeList = dataList.map((item) {
            debugPrint('📝 Processing employee item: $item');
            
            // Format date from ISO string to DD-MM-YYYY HH:MM format
            String formatDateTime(String? isoDate) {
              if (isoDate == null || isoDate.isEmpty) return '';
              try {
                // Handle both "YYYY-MM-DD HH:MM:SS" and ISO format
                final date = DateTime.parse(isoDate.replaceAll(' ', 'T'));
                return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              } catch (e) {
                debugPrint('Error parsing date: $isoDate');
                return isoDate;
              }
            }
            
            return {
              'id': item['id']?.toString() ?? '',
              'type': item['type'] ?? '',
              'name': item['name'] ?? '',
              'phone_no': item['phone_number'] ?? '',
              'unit': item['unit'] ?? '',
              'company': item['company_name'] ?? '',
              'address': item['address'] ?? '',
              'email': item['email'] ?? '',
              'person_to_meet': item['employee_name'] ?? '',
              'employee_code': item['employee_code'] ?? '',
              'department': item['department_name'] ?? '',
              'doc_type': item['doc_type'] ?? '',
              'doc_number': item['doc_number'] ?? '',
              'purpose': item['purpose'] ?? '',
              'status': item['approval_status'] ?? '',
              'created_at': formatDateTime(item['created_at']),
              'time_approved': formatDateTime(item['updated_at']),
              'reject_reason': item['reject_reason'] ?? '',
              'is_vip': item['is_vip'] ?? false,
            };
          }).toList();
          
          debugPrint('✅ Successfully parsed ${employeeList.length} employees');
          return employeeList;
        } else {
          debugPrint('⚠️ No data field found in response or status not success');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to load employee data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in fetchEmployees: $e');
      rethrow;
    }
  }

  /// Update employee status (Approve or Reject)
  Future<bool> updateEmployeeStatus(String visitorId, String action) async {
    try {
      debugPrint('🔗 Starting employee status update...');
      debugPrint('📝 Visitor ID: $visitorId');
      debugPrint('📝 Action: $action');
      
      // Prepare the request data - using visitor_id and action as per API requirement
      final requestData = {
        'visitor_id': visitorId,
        'action': action.toLowerCase(), // 'approve' or 'reject'
      };
      
      debugPrint('📤 Updating employee status with data: $requestData');
      
      // Construct the API endpoint
      const endpoint = '/visitors/employee-screen/';
      debugPrint('🔗 Updating at: $endpoint');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'POST',
        body: requestData,
      );
      
      debugPrint('📊 Update Response status: ${response.statusCode}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      // Limit response body to 200 characters maximum
      final responseBody = response.body;
      if (responseBody.length > 200) {
        final truncated = responseBody.substring(0, 200);
        debugPrint('📄 Update Response: $truncated... (${responseBody.length - 200} more chars)');
      } else {
        debugPrint('📄 Update Response: $responseBody');
      }
      
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('✅ Employee status updated successfully');
          
          // Check if update was successful
          if (responseData['success'] == true || responseData['status'] == 'success') {
            debugPrint('✅ Employee status update confirmed');
            return true;
          } else {
            debugPrint('⚠️ Employee status update may have failed');
            return false;
          }
        } catch (e) {
          debugPrint('⚠️ Response is not JSON (likely HTML page returned)');
          return false;
        }
      } else {
        debugPrint('❌ Update API Error: ${response.statusCode}');
        throw Exception('Failed to update employee status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in updateEmployeeStatus: $e');
      rethrow;
    }
  }
}