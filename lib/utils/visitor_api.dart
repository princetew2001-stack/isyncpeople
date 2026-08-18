import 'dart:convert';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class VisitorApiService {
  final AuthService _authService = AuthService();

  /// Fetch visitor data from the API with optional filters
  Future<List<Map<String, dynamic>>> fetchVisitors({
    String? fromDate,
    String? toDate,
    String? name,
    String? approvalStatus,
    String? unit,
  }) async {
    try {
      debugPrint('🔗 Starting visitor API call with filters...');
      
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
      
      if (approvalStatus != null && approvalStatus.isNotEmpty && approvalStatus != 'All') {
        queryParams['approval_status'] = approvalStatus;
        debugPrint('📋 Status filter: $approvalStatus');
      }
      
      if (unit != null && unit.isNotEmpty && unit != 'All') {
        queryParams['unit'] = unit;
        debugPrint('🏢 Unit filter: $unit');
      }
      
      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      // Construct the API endpoint with filters
      final endpoint = '/visitors/employee-screen/?$queryString';
      debugPrint('🔗 Fetching visitor data from: $endpoint');
      
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
        debugPrint('✅ Visitor data fetched successfully');
        debugPrint('📋 Response data structure: ${responseData.keys}');
        
        // Parse the response data
        if (responseData['visitors'] != null) {
          final List<dynamic> dataList = responseData['visitors'];
          debugPrint('📊 Found ${dataList.length} visitors');
          
          final List<Map<String, dynamic>> visitorList = dataList.map((item) {
            debugPrint('📝 Processing visitor item: $item');
            
            // Format date from ISO string to DD-MM-YYYY HH:MM format
            String formatDateTime(String? isoDate) {
              if (isoDate == null || isoDate.isEmpty) return '';
              try {
                final date = DateTime.parse(isoDate);
                return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              } catch (e) {
                debugPrint('Error parsing date: $isoDate');
                return isoDate;
              }
            }
            
            return {
              'srNo': item['id']?.toString() ?? '',
              'visitorName': item['visitor_name'] ?? '',
              'phoneNo': item['phone_no'] ?? '',
              'dateTime': formatDateTime(item['visit_date']),
              'unit': item['unit'] ?? '',
              'company': item['company'] ?? '',
              'address': item['address'] ?? '',
              'email': item['email'] ?? '',
              'personToMeet': item['person_to_meet'] ?? '',
              'approvalStatus': item['approval_status'] ?? '',
              'timeApproved': formatDateTime(item['approved_time']),
              'rejectReason': item['reject_reason'] ?? '',
              'employeeActions': _getActionText(item['approval_status']),
            };
          }).toList();
          
          debugPrint('✅ Successfully parsed ${visitorList.length} visitors');
          return visitorList;
        } else {
          debugPrint('⚠️ No visitors field found in response');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        debugPrint('❌ Error response: ${response.body}');
        throw Exception('Failed to load visitor data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in fetchVisitors: $e');
      rethrow;
    }
  }

  /// Get action text based on approval status
  String _getActionText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Approve/Reject';
      case 'approved':
      case 'rejected':
        return 'View Details';
      default:
        return 'View Details';
    }
  }

  /// Approve a visitor
  Future<bool> approveVisitor(String visitorId) async {
    try {
      debugPrint('🔗 Starting visitor approval...');
      debugPrint('📝 Visitor ID to approve: $visitorId');
      
      // Prepare the request data
      final requestData = {
        'visitor_id': visitorId,
        'action': 'approve',
      };
      
      debugPrint('📤 Approving visitor with data: $requestData');
      
      // Construct the API endpoint
      const endpoint = '/visitors/employee-screen/';
      debugPrint('🔗 Approving at: $endpoint');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'POST',
        body: requestData,
      );
      
      debugPrint('📊 Approve Response status: ${response.statusCode}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      // Limit response body to 200 characters maximum
      final responseBody = response.body;
      if (responseBody.length > 200) {
        final truncated = responseBody.substring(0, 200);
        debugPrint('📄 Approve Response: $truncated... (${responseBody.length - 200} more chars)');
      } else {
        debugPrint('📄 Approve Response: $responseBody');
      }
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Visitor approved successfully');
        
        // Check if approval was successful
        if (responseData['success'] == true || responseData['status'] == 'success') {
          debugPrint('✅ Visitor approval confirmed');
          return true;
        } else {
          debugPrint('⚠️ Visitor approval may have failed');
          return false;
        }
      } else {
        debugPrint('❌ Approve API Error: ${response.statusCode}');
        throw Exception('Failed to approve visitor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in approveVisitor: $e');
      rethrow;
    }
  }

  /// Reject a visitor
  Future<bool> rejectVisitor(String visitorId, String reason) async {
    try {
      debugPrint('🔗 Starting visitor rejection...');
      debugPrint('📝 Visitor ID to reject: $visitorId');
      debugPrint('📝 Rejection reason: $reason');
      
      // Prepare the request data
      final requestData = {
        'visitor_id': visitorId,
        'action': 'reject',
        'reject_reason': reason,
      };
      
      debugPrint('📤 Rejecting visitor with data: $requestData');
      
      // Construct the API endpoint
      const endpoint = '/visitors/employee-screen/';
      debugPrint('🔗 Rejecting at: $endpoint');
      
      // Make the authenticated API request
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'POST',
        body: requestData,
      );
      
      debugPrint('📊 Reject Response status: ${response.statusCode}');
      
      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);
      
      // Limit response body to 200 characters maximum
      final responseBody = response.body;
      if (responseBody.length > 200) {
        final truncated = responseBody.substring(0, 200);
        debugPrint('📄 Reject Response: $truncated... (${responseBody.length - 200} more chars)');
      } else {
        debugPrint('📄 Reject Response: $responseBody');
      }
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Visitor rejected successfully');
        
        // Check if rejection was successful
        if (responseData['success'] == true || responseData['status'] == 'success') {
          debugPrint('✅ Visitor rejection confirmed');
          return true;
        } else {
          debugPrint('⚠️ Visitor rejection may have failed');
          return false;
        }
      } else {
        debugPrint('❌ Reject API Error: ${response.statusCode}');
        throw Exception('Failed to reject visitor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Network error in rejectVisitor: $e');
      rethrow;
    }
  }
}