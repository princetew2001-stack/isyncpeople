import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class ApplicationApprovalApiService {
  final AuthService _authService = AuthService();
  
  /// Fetch pending applications for approval
  Future<List<Map<String, dynamic>>> fetchPendingApplications() async {
    try {
      debugPrint('🔄 Fetching pending applications for approval...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy application approval data');
        return DummyDataService.getDummyApplicationApprovalData();
      }
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Construct the API endpoint
      final endpoint = '/ess/application-approval/?manager_id=$empPaycode&status=pending';
      debugPrint('🔗 Fetching pending applications from: $endpoint');
      
      // Make authenticated request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );
      
      debugPrint('📊 Response status: ${response.statusCode}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Pending applications fetched successfully');
        
        if (responseData['data'] != null && responseData['data'] is List) {
          final List<dynamic> dataList = responseData['data'];
          
          return dataList.map((item) => {
            'id': item['id']?.toString() ?? '',
            'type': item['type']?.toString() ?? '',
            'employee_name': item['employee_name']?.toString() ?? '',
            'employee_id': item['employee_id']?.toString() ?? '',
            'application_type': item['application_type']?.toString() ?? '',
            'from_date': item['from_date']?.toString() ?? '',
            'to_date': item['to_date']?.toString() ?? '',
            'days': item['days']?.toString() ?? '',
            'reason': item['reason']?.toString() ?? '',
            'status': item['status']?.toString() ?? '',
            'applied_date': item['applied_date']?.toString() ?? '',
            'department': item['department']?.toString() ?? '',
          }).toList().cast<Map<String, dynamic>>();
        }
        
        return [];
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch pending applications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching pending applications: $e');
      rethrow;
    }
  }
  
  /// Approve or reject an application
  Future<bool> updateApplicationStatus(String applicationId, String action, {String? remarks}) async {
    try {
      debugPrint('🔄 Updating application status...');
      debugPrint('📝 Application ID: $applicationId, Action: $action');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - simulating application status update');
        // Simulate a delay
        await Future.delayed(const Duration(seconds: 1));
        return true;
      }
      
      // Prepare the request data
      final requestData = {
        'application_id': applicationId,
        'action': action.toLowerCase(), // 'approve' or 'reject'
        'remarks': remarks ?? '',
      };
      
      debugPrint('📤 Updating application with data: $requestData');
      
      // Construct the API endpoint
      const endpoint = '/ess/application-approval/';
      
      // Make authenticated request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'POST',
        body: requestData,
      );
      
      debugPrint('📊 Update Response status: ${response.statusCode}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('✅ Application status updated successfully');
          
          return responseData['success'] == true || responseData['status'] == 'success';
        } catch (e) {
          debugPrint('⚠️ Response is not JSON (likely HTML page returned)');
          return true; // Assume success if we get a 200 response
        }
      } else {
        debugPrint('❌ Update API Error: ${response.statusCode}');
        throw Exception('Failed to update application status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating application status: $e');
      rethrow;
    }
  }
}