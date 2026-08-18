import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ClaimApprovalApiService {
  static const String _endpoint =
      'https://delton.intellisync.in:11004/claims/approval-screen/?json=1';

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> fetchClaimApprovals() async {
    try {
      debugPrint('🔄 Fetching claim approvals from API...');

      final response = await _authService.authenticatedRequest(
        endpoint: _endpoint,
        method: 'GET',
      );

      debugPrint('📊 Claim approvals response status: ${response.statusCode}');

      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('✅ Claim approvals fetched successfully');

        final List<dynamic> rawClaims = responseData['claims'] ?? [];
        final List<Map<String, dynamic>> claims = rawClaims.map((item) {
          return {
            'id': item['id']?.toString() ?? '',
            'claimNo': item['claim_no']?.toString() ?? '',
            'claimType': _capitalizeFirst(item['claim_type']?.toString() ?? ''),
            'purpose': item['purpose']?.toString() ?? '',
            'employeeName': item['employee_name']?.toString() ?? '-',
            'date': _formatDate(item['date']?.toString()),
            'amount': item['amount']?.toString() ?? '0.00',
            'reportingStatus': item['reporting_status']?.toString() ?? 'Pending',
            'managementStatus': item['management_status']?.toString() ?? 'Pending',
            'accountsStatus': item['accounts_status']?.toString() ?? 'Pending',
            'reportingId': item['reporting_id']?.toString() ?? '',
            'managementId': item['management_id']?.toString() ?? '',
            'isReportingUser': item['is_reporting_user'] ?? false,
            'isManagementUser': item['is_management_user'] ?? false,
            'isAccountsUser': item['is_accounts_user'] ?? false,
            'canSeeReporting': item['can_see_reporting'] ?? true,
            'canSeeManagement': item['can_see_management'] ?? true,
            'canSeeAccounts': item['can_see_accounts'] ?? true,
          };
        }).toList();

        return {
          'claims': claims,
          'isReporting': responseData['is_reporting'] ?? false,
          'isManagement': responseData['is_management'] ?? false,
          'isAccounts': responseData['is_accounts'] ?? false,
          'currentUserId': responseData['current_user_id']?.toString() ?? '',
        };
      } else {
        throw Exception(
            'Failed to fetch claim approvals: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching claim approvals: $e');
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

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}
