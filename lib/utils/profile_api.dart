import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ProfileApi {
  final AuthService _authService = AuthService();

  static const String _endpoint = '/ess/employee_profile/?json=1';

  /// Fetch employee profile data from the API.
  /// Returns the parsed [employee] map from the JSON response, or null on failure.
  Future<Map<String, dynamic>?> fetchProfile() async {
    debugPrint('🔄 ProfileApi.fetchProfile: calling $_endpoint');
    try {
      final response = await _authService.authenticatedRequest(
        endpoint: _endpoint,
        method: 'GET',
      );

      debugPrint('📊 ProfileApi.fetchProfile: status=${response.statusCode}');
      debugPrint('📄 ProfileApi.fetchProfile: body preview=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        debugPrint('🔍 ProfileApi.fetchProfile: top-level keys=${body is Map ? body.keys.toList() : "not a map"}');

        // The view returns: { employee: {...}, is_existing: bool, ... }
        if (body is Map<String, dynamic> && body.containsKey('employee')) {
          final employee = body['employee'];
          if (employee is Map<String, dynamic>) {
            debugPrint('✅ ProfileApi.fetchProfile: employee keys=${employee.keys.toList()}');
            debugPrint('👤 ProfileApi.fetchProfile: emp_name=${employee['emp_name']}, emp_code=${employee['emp_code']}, pay_code=${employee['pay_code']}');
            debugPrint('🏢 ProfileApi.fetchProfile: department=${employee['department']}, designation=${employee['designation']}');
            debugPrint('📅 ProfileApi.fetchProfile: doj=${employee['doj']}, dob=${employee['dob']}');
            debugPrint('📧 ProfileApi.fetchProfile: official_email=${employee['official_email']}');
            debugPrint('🆔 ProfileApi.fetchProfile: pan_no=${employee['pan_no']}, aadhar_no=${employee['aadhar_no']}, uan_no=${employee['uan_no']}');
            debugPrint('🏠 ProfileApi.fetchProfile: pres_address=${employee['pres_address']}, pres_city=${employee['pres_city']}');
            debugPrint('📚 ProfileApi.fetchProfile: qualifications count=${employee['qualifications'] is List ? (employee['qualifications'] as List).length : 0}');
            debugPrint('🛠️ ProfileApi.fetchProfile: skills count=${employee['skills'] is List ? (employee['skills'] as List).length : 0}');
            debugPrint('💼 ProfileApi.fetchProfile: experiences count=${employee['experiences'] is List ? (employee['experiences'] as List).length : 0}');
            return employee;
          }
        }

        debugPrint('⚠️ ProfileApi.fetchProfile: unexpected response shape — no "employee" key');
        debugPrint('⚠️ ProfileApi.fetchProfile: full body=$body');
        return null;
      } else {
        debugPrint('❌ ProfileApi.fetchProfile: HTTP ${response.statusCode}');
        debugPrint('❌ ProfileApi.fetchProfile: error body=${response.body}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('❌ ProfileApi.fetchProfile: exception=$e');
      debugPrint('❌ ProfileApi.fetchProfile: stacktrace=$stack');
      return null;
    }
  }

  /// Submit profile update to POST /ess/employee_profile/
  Future<ProfileSubmitResult> submitProfile(Map<String, String> formData) async {
    debugPrint('🔄 ProfileApi.submitProfile: posting to /ess/employee_profile/');
    debugPrint('📤 ProfileApi.submitProfile: form fields=${formData.keys.toList()}');
    try {
      final response = await _authService.authenticatedFormRequest(
        endpoint: '/ess/employee_profile/',
        formData: formData,
      );

      debugPrint('📊 ProfileApi.submitProfile: status=${response.statusCode}');
      debugPrint('📄 ProfileApi.submitProfile: body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      // Check for 401 Unauthorized
      await AuthService.checkAndHandle401(response);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final body = response.body.toLowerCase();
        if (body.contains('error') && !body.contains('success')) {
          debugPrint('❌ ProfileApi.submitProfile: error detected in response body');
          return const ProfileSubmitResult(success: false, message: 'Submission failed. Please check your data.');
        }
        debugPrint('✅ ProfileApi.submitProfile: submission successful');
        return const ProfileSubmitResult(success: true, message: 'Profile update submitted for HR approval.');
      } else if (response.statusCode == 400) {
        debugPrint('❌ ProfileApi.submitProfile: 400 bad request');
        return const ProfileSubmitResult(success: false, message: 'Invalid data. Please check your inputs.');
      } else {
        debugPrint('❌ ProfileApi.submitProfile: unexpected status ${response.statusCode}');
        return ProfileSubmitResult(success: false, message: 'Server error (${response.statusCode}). Please try again.');
      }
    } catch (e, stack) {
      debugPrint('❌ ProfileApi.submitProfile: exception=$e');
      debugPrint('❌ ProfileApi.submitProfile: stacktrace=$stack');
      return ProfileSubmitResult(success: false, message: 'Network error: $e');
    }
  }

  static String str(Map<String, dynamic> data, String key) =>
      data[key]?.toString() ?? '';

  static List<Map<String, String>> parseQualifications(dynamic raw) {
    if (raw is! List) {
      debugPrint('⚠️ ProfileApi.parseQualifications: raw is not a List (${raw.runtimeType}), returning empty entry');
      return [{'degree': '', 'year': '', 'specialization': ''}];
    }
    final list = raw
        .whereType<Map>()
        .map<Map<String, String>>((q) => {
              'degree': q['degree']?.toString() ?? '',
              'year': q['year']?.toString() ?? '',
              'specialization': q['specialization']?.toString() ?? '',
            })
        .toList();
    debugPrint('📚 ProfileApi.parseQualifications: parsed ${list.length} entries');
    return list.isEmpty ? [{'degree': '', 'year': '', 'specialization': ''}] : list;
  }

  static List<Map<String, String>> parseSkills(dynamic raw) {
    if (raw is! List) {
      debugPrint('⚠️ ProfileApi.parseSkills: raw is not a List (${raw.runtimeType}), returning empty entry');
      return [{'skill': '', 'level': '', 'exp_years': '', 'comment': ''}];
    }
    final list = raw
        .whereType<Map>()
        .map<Map<String, String>>((s) => {
              'skill': s['name']?.toString() ?? '',
              'level': s['level']?.toString() ?? '',
              'exp_years': s['experience_years']?.toString() ?? '',
              'comment': s['comments']?.toString() ?? '',
            })
        .toList();
    debugPrint('🛠️ ProfileApi.parseSkills: parsed ${list.length} entries');
    return list.isEmpty ? [{'skill': '', 'level': '', 'exp_years': '', 'comment': ''}] : list;
  }

  static List<Map<String, String>> parseExperiences(dynamic raw) {
    if (raw is! List) {
      debugPrint('⚠️ ProfileApi.parseExperiences: raw is not a List (${raw.runtimeType}), returning empty entry');
      return [{'employer': '', 'designation': '', 'from': '', 'to': '', 'ctc': '', 'location': ''}];
    }
    final list = raw
        .whereType<Map>()
        .map<Map<String, String>>((e) => {
              'employer': e['employer']?.toString() ?? '',
              'designation': e['designation']?.toString() ?? '',
              'from': e['from_date']?.toString() ?? '',
              'to': e['to_date']?.toString() ?? '',
              'ctc': e['ctc']?.toString() ?? '',
              'location': e['location']?.toString() ?? '',
            })
        .toList();
    debugPrint('💼 ProfileApi.parseExperiences: parsed ${list.length} entries');
    return list.isEmpty
        ? [{'employer': '', 'designation': '', 'from': '', 'to': '', 'ctc': '', 'location': ''}]
        : list;
  }

  static String parseHobbies(dynamic raw, String category) {
    if (raw is! List) {
      debugPrint('⚠️ ProfileApi.parseHobbies[$category]: raw is not a List');
      return '';
    }
    final result = raw
        .whereType<Map>()
        .where((h) => h['category']?.toString() == category)
        .map((h) => h['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
    debugPrint('🎯 ProfileApi.parseHobbies[$category]: "$result"');
    return result;
  }

  /// Format a date string to MM / DD / YYYY display format.
  /// Accepts common formats: YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY, MM/DD/YYYY.
  static String formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      // Strip time component if present (e.g. 1994-06-08T00:00:00)
      final cleaned = raw.contains('T') ? raw.split('T').first : raw.trim();

      // Try YYYY-MM-DD (ISO)
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
      final isoMatch = iso.firstMatch(cleaned);
      if (isoMatch != null) {
        final mm = isoMatch.group(2)!;
        final dd = isoMatch.group(3)!;
        final yyyy = isoMatch.group(1)!;
        return '$mm / $dd / $yyyy';
      }

      // Try DD-MM-YYYY or DD/MM/YYYY
      final dmy = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$');
      final dmyMatch = dmy.firstMatch(cleaned);
      if (dmyMatch != null) {
        final dd = dmyMatch.group(1)!;
        final mm = dmyMatch.group(2)!;
        final yyyy = dmyMatch.group(3)!;
        return '$mm / $dd / $yyyy';
      }

      // Already some slash format — just normalise spacing
      if (cleaned.contains('/')) {
        final parts = cleaned.split('/').map((p) => p.trim()).toList();
        if (parts.length == 3) return parts.join(' / ');
      }
    } catch (_) {}
    return raw; // fallback: return as-is
  }
}

class ProfileSubmitResult {
  final bool success;
  final String message;
  const ProfileSubmitResult({required this.success, required this.message});
}
