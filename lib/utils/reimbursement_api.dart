import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ReimbursementApiService {
  static const String _endpoint =
      'https://delton.intellisync.in:11004/claims/reimbursement-log-history/?json=1';

  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>> fetchReimbursements() async {
    try {
      debugPrint('🔄 Fetching reimbursements from API...');

      final response = await _authService.authenticatedRequest(
        endpoint: _endpoint,
        method: 'GET',
      );

      debugPrint('📊 Reimbursements response status: ${response.statusCode}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['claims'] != null) {
          final List<dynamic> dataList = responseData['claims'];
          final List<Map<String, dynamic>> claims = dataList.map((item) {
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

          debugPrint('📋 Parsed ${claims.length} reimbursements');
          return claims;
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to fetch reimbursements: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching reimbursements: $e');
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
