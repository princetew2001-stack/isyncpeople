import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'dummy_data_service.dart';

class PayslipApiService {
  final AuthService _authService = AuthService();
  
  /// Fetch payslip data from API
  Future<Map<String, dynamic>> fetchPayslipData(String month, String year) async {
    try {
      debugPrint('🔄 Fetching payslip data for $month/$year...');
      
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy payslip data');
        return {
          'success': true,
          'data': [DummyDataService.getDummyPayslipData()],
        };
      }
      
      // Get employee paycode for the request
      final empPaycode = await _authService.getEmployeePaycode();
      if (empPaycode == null) {
        throw Exception('Employee paycode not found. Please login again.');
      }
      
      // Construct the API endpoint
      final endpoint = '/payroll/payslip/?emp_paycode=$empPaycode&month=$month&year=$year';
      debugPrint('🔗 Fetching payslip from: $endpoint');
      
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
        debugPrint('✅ Payslip data fetched successfully');
        
        return responseData;
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch payslip data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching payslip data: $e');
      rethrow;
    }
  }
  
  /// Get available payslip months/years
  Future<List<Map<String, String>>> getAvailablePayslips() async {
    try {
      // Check if this is the test user
      if (await DummyDataService.isTestUser()) {
        debugPrint('🧪 Test user detected - returning dummy payslip months');
        return [
          {'month': '2', 'year': '2026', 'display': 'February 2026'},
          {'month': '1', 'year': '2026', 'display': 'January 2026'},
          {'month': '12', 'year': '2025', 'display': 'December 2025'},
          {'month': '11', 'year': '2025', 'display': 'November 2025'},
        ];
      }
      
      // For real users, return current and previous months
      final now = DateTime.now();
      final List<Map<String, String>> months = [];
      
      for (int i = 0; i < 6; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        months.add({
          'month': date.month.toString(),
          'year': date.year.toString(),
          'display': '${_getMonthName(date.month)} ${date.year}',
        });
      }
      
      return months;
    } catch (e) {
      debugPrint('❌ Error getting available payslips: $e');
      return [];
    }
  }
  
  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}