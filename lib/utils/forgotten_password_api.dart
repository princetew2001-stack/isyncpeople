import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class ForgottenPasswordAPI {
  // Base domain
  static const String _baseUrl = 'https://delton.intellisync.in:11004';
  
  // API endpoints
  static const String _forgottenPasswordEndpoint = '/forgotten-password/';
  static const String _verifyOtpEndpoint = '/verify-otp/';
  static const String _resetPasswordEndpoint = '/reset-password/';
  
  /// Send OTP to user's registered email/phone
  /// 
  /// Parameters:
  /// - username: The username entered by the user
  /// 
  /// Returns:
  /// - Map with 'success' (bool) and 'message' (String)
  static Future<Map<String, dynamic>> sendOTP(String username) async {
    final url = Uri.parse('$_baseUrl$_forgottenPasswordEndpoint');
    
    debugPrint('🔗 Sending OTP request to: $url');
    debugPrint('📤 Request payload: username=$username');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': username,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏰ Request timed out after 15 seconds');
          throw Exception('Connection timeout - Server is not responding');
        },
      );

      debugPrint('✅ API Response received');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📋 Response Headers: ${response.headers}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          
          // Check for success - API returns "status": "success"
          bool isSuccess = false;
          String message = '';
          
          if (responseData.containsKey('status')) {
            final status = responseData['status'];
            isSuccess = status == 'success' || status == true;
          } else if (responseData.containsKey('success')) {
            isSuccess = responseData['success'] == true;
          } else {
            // If no clear success indicator, assume success for 200 status
            isSuccess = true;
          }
          
          // Get message
          if (responseData.containsKey('message')) {
            message = responseData['message'].toString();
          } else if (responseData.containsKey('msg')) {
            message = responseData['msg'].toString();
          } else {
            message = isSuccess ? 'OTP sent successfully' : 'Failed to send OTP';
          }
          
          debugPrint('🔍 Success check: isSuccess=$isSuccess, message=$message');
          
          return {
            'success': isSuccess,
            'message': message,
            'data': responseData,
          };
        } catch (jsonError) {
          debugPrint('❌ JSON parsing error: $jsonError');
          debugPrint('Raw response: ${response.body}');
          return {
            'success': false,
            'message': 'Invalid server response format',
          };
        }
      } else if (response.statusCode == 404) {
        debugPrint('❌ Not Found (404) - Username not found');
        return {
          'success': false,
          'message': 'Username not found',
        };
      } else if (response.statusCode >= 500) {
        debugPrint('❌ Server Error (${response.statusCode})');
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        debugPrint('❌ Unexpected status code: ${response.statusCode}');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to send OTP';
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Unexpected server response (${response.statusCode})',
          };
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('🌐 Network Error (ClientException): $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server. Please check your internet connection.',
      };
    } on FormatException catch (e) {
      debugPrint('📄 Format Error: $e');
      return {
        'success': false,
        'message': 'Server response format error',
      };
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
      if (e.toString().contains('timeout') || e.toString().contains('Connection timeout')) {
        return {
          'success': false,
          'message': 'Connection timeout: Server is taking too long to respond. Please try again.',
        };
      } else {
        return {
          'success': false,
          'message': 'Unexpected error occurred. Please try again.',
        };
      }
    }
  }
  
  /// Verify OTP entered by user
  /// 
  /// Parameters:
  /// - username: The username entered by the user
  /// - otp: The OTP code entered by the user
  /// 
  /// Returns:
  /// - Map with 'success' (bool) and 'message' (String)
  static Future<Map<String, dynamic>> verifyOTP(String username, String otp) async {
    final url = Uri.parse('$_baseUrl$_verifyOtpEndpoint');
    
    debugPrint('🔗 Verifying OTP at: $url');
    debugPrint('📤 Request payload: username=$username&otp=$otp');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': username,
          'otp': otp,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏰ Request timed out after 15 seconds');
          throw Exception('Connection timeout - Server is not responding');
        },
      );

      debugPrint('✅ API Response received');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📋 Response Headers: ${response.headers}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          
          // Check for success - API returns "status": "success"
          bool isSuccess = false;
          String message = '';
          
          if (responseData.containsKey('status')) {
            final status = responseData['status'];
            isSuccess = status == 'success' || status == true;
          } else if (responseData.containsKey('success')) {
            isSuccess = responseData['success'] == true;
          } else {
            // If no clear success indicator, assume success for 200 status
            isSuccess = true;
          }
          
          // Get message
          if (responseData.containsKey('message')) {
            message = responseData['message'].toString();
          } else if (responseData.containsKey('msg')) {
            message = responseData['msg'].toString();
          } else {
            message = isSuccess ? 'OTP verified successfully' : 'Invalid OTP';
          }
          
          debugPrint('🔍 Success check: isSuccess=$isSuccess, message=$message');
          
          return {
            'success': isSuccess,
            'message': message,
            'data': responseData,
          };
        } catch (jsonError) {
          debugPrint('❌ JSON parsing error: $jsonError');
          debugPrint('Raw response: ${response.body}');
          return {
            'success': false,
            'message': 'Invalid server response format',
          };
        }
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        debugPrint('❌ Invalid OTP (${response.statusCode})');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Invalid or expired OTP';
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid or expired OTP',
          };
        }
      } else if (response.statusCode >= 500) {
        debugPrint('❌ Server Error (${response.statusCode})');
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        debugPrint('❌ Unexpected status code: ${response.statusCode}');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to verify OTP';
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Unexpected server response (${response.statusCode})',
          };
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('🌐 Network Error (ClientException): $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server. Please check your internet connection.',
      };
    } on FormatException catch (e) {
      debugPrint('📄 Format Error: $e');
      return {
        'success': false,
        'message': 'Server response format error',
      };
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
      if (e.toString().contains('timeout') || e.toString().contains('Connection timeout')) {
        return {
          'success': false,
          'message': 'Connection timeout: Server is taking too long to respond. Please try again.',
        };
      } else {
        return {
          'success': false,
          'message': 'Unexpected error occurred. Please try again.',
        };
      }
    }
  }
  
  /// Reset password with new password
  /// 
  /// Parameters:
  /// - username: The username entered by the user
  /// - newPassword: The new password entered by the user
  /// 
  /// Returns:
  /// - Map with 'success' (bool) and 'message' (String)
  static Future<Map<String, dynamic>> resetPassword(String username, String newPassword) async {
    final url = Uri.parse('$_baseUrl$_resetPasswordEndpoint');
    
    debugPrint('🔗 Resetting password at: $url');
    debugPrint('📤 Request payload: username=$username&new_password=***');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': username,
          'new_password': newPassword,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⏰ Request timed out after 15 seconds');
          throw Exception('Connection timeout - Server is not responding');
        },
      );

      debugPrint('✅ API Response received');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📋 Response Headers: ${response.headers}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          
          // Check for success - API returns "status": "success"
          bool isSuccess = false;
          String message = '';
          
          if (responseData.containsKey('status')) {
            final status = responseData['status'];
            isSuccess = status == 'success' || status == true;
          } else if (responseData.containsKey('success')) {
            isSuccess = responseData['success'] == true;
          } else {
            // If no clear success indicator, assume success for 200 status
            isSuccess = true;
          }
          
          // Get message
          if (responseData.containsKey('message')) {
            message = responseData['message'].toString();
          } else if (responseData.containsKey('msg')) {
            message = responseData['msg'].toString();
          } else {
            message = isSuccess ? 'Password reset successfully' : 'Failed to reset password';
          }
          
          debugPrint('🔍 Success check: isSuccess=$isSuccess, message=$message');
          
          return {
            'success': isSuccess,
            'message': message,
            'data': responseData,
          };
        } catch (jsonError) {
          debugPrint('❌ JSON parsing error: $jsonError');
          debugPrint('Raw response: ${response.body}');
          return {
            'success': false,
            'message': 'Invalid server response format',
          };
        }
      } else if (response.statusCode == 400) {
        debugPrint('❌ Bad Request (400)');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Invalid password format';
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid password format',
          };
        }
      } else if (response.statusCode >= 500) {
        debugPrint('❌ Server Error (${response.statusCode})');
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      } else {
        debugPrint('❌ Unexpected status code: ${response.statusCode}');
        
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ?? errorData['error'] ?? 'Failed to reset password';
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Unexpected server response (${response.statusCode})',
          };
        }
      }
    } on http.ClientException catch (e) {
      debugPrint('🌐 Network Error (ClientException): $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server. Please check your internet connection.',
      };
    } on FormatException catch (e) {
      debugPrint('📄 Format Error: $e');
      return {
        'success': false,
        'message': 'Server response format error',
      };
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
      if (e.toString().contains('timeout') || e.toString().contains('Connection timeout')) {
        return {
          'success': false,
          'message': 'Connection timeout: Server is taking too long to respond. Please try again.',
        };
      } else {
        return {
          'success': false,
          'message': 'Unexpected error occurred. Please try again.',
        };
      }
    }
  }
}
