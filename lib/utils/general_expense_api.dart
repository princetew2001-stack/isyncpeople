import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class GeneralExpenseApiService {
  static const String _endpoint =
      'https://delton.intellisync.in:11004/claims/general-expenses-history/?json=1';

  final AuthService _authService = AuthService();

  /// Fetch general expense history from API
  Future<List<Map<String, dynamic>>> fetchGeneralExpenses() async {
    try {
      debugPrint('🔄 Fetching general expenses from API...');

      final response = await _authService.authenticatedRequest(
        endpoint: _endpoint,
        method: 'GET',
      );

      debugPrint('📊 General expenses response status: ${response.statusCode}');
      debugPrint('📄 General expenses response body: ${response.body}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ General expenses fetched successfully');

        if (responseData['claims'] != null) {
          final List<dynamic> dataList = responseData['claims'];
          final List<Map<String, dynamic>> expenses = dataList.map((item) {
            return {
              'id': item['id']?.toString() ?? '',
              'claimNo': item['claim_no']?.toString() ?? '',
              'claimDate': _formatDate(item['claim_date']?.toString()),
              'employeeName': item['employee_name']?.toString() ?? '',
              'department': item['department']?.toString() ?? '',
              'purpose': item['purpose']?.toString() ?? '',
              'totalAmount': item['total_amount']?.toString() ?? '0.00',
              'status': item['status']?.toString() ?? '',
              'approvedBy': item['approved_by']?.toString() ?? '-',
              'approvedDate': _formatDate(item['approved_date']?.toString()),
            };
          }).toList();

          debugPrint('📋 Parsed ${expenses.length} general expenses');
          return expenses;
        } else {
          debugPrint('⚠️ No claims data found in response');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch general expenses: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching general expenses: $e');
      rethrow;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') return '-';
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day-$month-$year';
    } catch (e) {
      return dateStr;
    }
  }
}
