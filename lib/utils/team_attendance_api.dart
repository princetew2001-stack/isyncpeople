import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class TeamAttendanceApiService {
  final AuthService _authService = AuthService();
  
  /// Fetch team attendance data from API
  Future<List<Map<String, dynamic>>> fetchTeamAttendance({String? date}) async {
    try {
      debugPrint('🔄 Fetching team attendance data...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy team attendance data');
        return DummyDataService.getDummyTeamAttendanceData();
      }
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Use current date if not provided
      final targetDate = date ?? DateTime.now().toIso8601String().split('T')[0];
      
      // Construct the API endpoint
      final endpoint = '/attendance/team/?date=$targetDate&manager_id=$empPaycode';
      debugPrint('🔗 Fetching team attendance from: $endpoint');
      
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
        debugPrint('✅ Team attendance data fetched successfully');
        
        if (responseData['data'] != null && responseData['data'] is List) {
          final List<dynamic> dataList = responseData['data'];
          
          return dataList.map((item) => {
            'emp_id': item['emp_id']?.toString() ?? '',
            'name': item['name']?.toString() ?? '',
            'designation': item['designation']?.toString() ?? '',
            'status': item['status']?.toString() ?? '',
            'check_in_time': item['check_in_time']?.toString() ?? '',
            'check_out_time': item['check_out_time']?.toString() ?? '',
            'work_duration': item['work_duration']?.toString() ?? '',
            'location': item['location']?.toString() ?? '',
          }).toList().cast<Map<String, dynamic>>();
        }
        
        return [];
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch team attendance: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching team attendance: $e');
      rethrow;
    }
  }
}