import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class TravelClaimApiService {
  static const String _endpoint =
      'https://delton.intellisync.in:11004/claims/travel-claim-history/?json=1';

  final AuthService _authService = AuthService();

  /// Fetch travel claim history from API
  Future<List<Map<String, dynamic>>> fetchTravelClaims() async {
    try {
      debugPrint('🔄 Fetching travel claims from API...');

      final response = await _authService.authenticatedRequest(
        endpoint: _endpoint,
        method: 'GET',
      );

      debugPrint('📊 Travel claims response status: ${response.statusCode}');
      debugPrint('📄 Travel claims response body: ${response.body}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Travel claims fetched successfully');

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

          debugPrint('📋 Parsed ${claims.length} travel claims');
          return claims;
        } else {
          debugPrint('⚠️ No claims data found in response');
          return [];
        }
      } else {
        debugPrint('❌ API Error: ${response.statusCode}');
        throw Exception('Failed to fetch travel claims: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching travel claims: $e');
      rethrow;
    }
  }

  /// Format date string to DD-MM-YYYY
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
