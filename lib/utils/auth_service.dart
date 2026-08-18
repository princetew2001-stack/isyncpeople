import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'https://delton.intellisync.in:11004';
  static const String _loginEndpoint = '/app-login/';
  
  // Getter for base URL
  String get baseUrl => _baseUrl;
  
  // Callback for 401 unauthorized errors (redirect to login)
  static void Function()? onUnauthorized;
  
 
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  /// Check if user has valid authentication
  Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final sessionCookies = prefs.getString('session_cookies');
      
      if (!isLoggedIn || sessionCookies == null) {
        return false;
      }
      
      
      return true;
    } catch (e) {
      debugPrint('❌ Error checking authentication: $e');
      return false;
    }
  }
  
  /// Get session cookies for API requests
  Future<String> getSessionCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookies') ?? '';
    } catch (e) {
      debugPrint('❌ Error getting session cookies: $e');
      return '';
    }
  }
  


  /// Get session info (sessionid and CSRF token) from dedicated endpoint
  Future<Map<String, String>?> getSessionInfo() async {
    try {
      debugPrint('🔄 Fetching session info from dedicated endpoint...');
      
      
      const url = 'https://delton.intellisync.in:11004/session_info/';
      final cookies = await getSessionCookies();
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Cookie': cookies,
        'User-Agent': 'AttendanceApp/1.0',
      };

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      debugPrint('📊 Session info response status: ${response.statusCode}');
      debugPrint('📄 Session info response body (first 200 chars): ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      
      if (response.statusCode == 200) {
        // Check if response is JSON
        if (response.body.trim().startsWith('{')) {
          try {
            final responseData = jsonDecode(response.body);
            debugPrint('✅ Session info fetched successfully');
            
            // Extract from the 'data' object in the response
            final data = responseData['data'];
            final sessionId = data['session_id']?.toString();
            final csrfToken = data['csrf_token']?.toString();
            
            if (sessionId != null && csrfToken != null) {
              debugPrint('🔐 Session ID: ${sessionId.substring(0, 8)}...');
              debugPrint('🔐 CSRF Token: ${csrfToken.substring(0, 8)}...');
              
              // Store the session info
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('session_cookies', 'sessionid=$sessionId');
              await prefs.setString('csrf_token', csrfToken);
              await prefs.setString('login_time', DateTime.now().toIso8601String());
              await prefs.setBool('is_logged_in', true);
              
              return {
                'sessionid': sessionId,
                'csrf_token': csrfToken,
              };
            } else {
              debugPrint('❌ Session info incomplete in response: sessionid=$sessionId, csrf_token=$csrfToken');
              return null;
            }
          } catch (e) {
            debugPrint('❌ Failed to parse JSON response: $e');
            debugPrint('❌ Response was: ${response.body}');
            return null;
          }
        } else {
          debugPrint('❌ Response is not JSON (probably HTML login page)');
          debugPrint('❌ This usually means authentication is required or endpoint doesn\'t exist');
          return null;
        }
      } else {
        debugPrint('❌ Failed to fetch session info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching session info: $e');
      return null;
    }
  }

  /// Get stored CSRF token
  Future<String?> getStoredCsrfToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final csrfToken = prefs.getString('csrf_token');
      if (csrfToken != null) {
        debugPrint('✅ Using stored CSRF token: ${csrfToken.substring(0, 8)}...');
        return csrfToken;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting stored CSRF token: $e');
      return null;
    }
  }

  /// Get authenticated HTTP headers
  Future<Map<String, String>> getAuthHeaders() async {
    final cookies = await getSessionCookies();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Cookie': cookies,
      'User-Agent': 'AttendanceApp/1.0',
    };
  }

  /// Get authenticated HTTP headers with CSRF token
  Future<Map<String, String>> getAuthHeadersWithCsrf() async {
    final cookies = await getSessionCookies();
    var csrfToken = await getStoredCsrfToken();
    
    // If no stored CSRF token, try to get fresh session info
    if (csrfToken == null || csrfToken.isEmpty) {
      debugPrint('⚠️ No stored CSRF token, fetching fresh session info...');
      final sessionInfo = await getSessionInfo();
      if (sessionInfo != null) {
        csrfToken = sessionInfo['csrf_token'];
      }
    }
    
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Cookie': cookies,
      'User-Agent': 'AttendanceApp/1.0',
      'Referer': _baseUrl,  // Required for Django CSRF validation
      'Origin': _baseUrl,   // Required for Django CSRF validation
    };
    
    if (csrfToken != null && csrfToken.isNotEmpty) {
      headers['X-CSRFToken'] = csrfToken;
      headers['X-Csrftoken'] = csrfToken; // Alternative case
      headers['HTTP_X_CSRFTOKEN'] = csrfToken; // Alternative format
      debugPrint('🔐 Added CSRF token to headers (multiple formats)');
      debugPrint('✅ Using stored CSRF token: ${csrfToken.substring(0, 8)}...');
    } else {
      debugPrint('❌ Failed to get CSRF token');
    }
    
    return headers;
  }
  
  /// Authenticate user and store session
  Future<AuthResult> authenticate({String? username, String? password}) async {
    try {
      // If no credentials provided, try to use stored ones
      if (username == null || password == null) {
        final prefs = await SharedPreferences.getInstance();
        username ??= prefs.getString('user_email') ?? '';
        password ??= prefs.getString('user_password') ?? '';
        
        if (username.isEmpty || password.isEmpty) {
          return AuthResult(
            success: false,
            message: 'No stored credentials found',
          );
        }
      }
      
      debugPrint('🔄 Authenticating user: $username');
      
      final response = await http.post(
        Uri.parse('$_baseUrl$_loginEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('📊 Auth response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Extract and store session cookies
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          debugPrint('🍪 Login cookies received: $cookies');
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('session_cookies', cookies);
          await prefs.setString('login_time', DateTime.now().toIso8601String());
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_email', username);
          
          debugPrint('✅ Authentication successful, session stored');
          
          // Parse response data if available
          try {
            final responseData = jsonDecode(response.body);
            return AuthResult(
              success: true,
              message: 'Authentication successful',



              
              data: responseData,
            );
          } catch (e) {
            return AuthResult(
              success: true,
              message: 'Authentication successful',
            );
          }
        } else {
          return AuthResult(
            success: false,
            message: 'No session cookies received',
          );
        }
      } else if (response.statusCode == 401) {
        return AuthResult(
          success: false,
          message: 'Invalid username or password',
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Authentication failed (${response.statusCode})',
        );
      }
    } catch (e) {
      debugPrint('❌ Authentication error: $e');
      return AuthResult(
        success: false,
        message: 'Network error: ${e.toString()}',
      );
    }
  }
  
  /// Make authenticated form request (for form-encoded data)
  Future<http.Response> authenticatedFormRequest({
    required String endpoint,
    required Map<String, String> formData,
    Map<String, String>? additionalHeaders,
  }) async {
    // Check if authenticated
    if (!await isAuthenticated()) {
      // Try to re-authenticate
      final authResult = await authenticate();
      if (!authResult.success) {
        throw Exception('Authentication required: ${authResult.message}');
      }
    }
    
    final url = endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint';
    
    debugPrint('📝 Making authenticated form request to: $url');
    debugPrint('📤 Form data: $formData');
    
    // Get headers with CSRF token
    final headers = await getAuthHeadersWithCsrf();
    headers['Content-Type'] = 'application/x-www-form-urlencoded';
    
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    // Add CSRF token to form data as well
    final csrfToken = await getStoredCsrfToken();
    if (csrfToken != null && csrfToken.isNotEmpty) {
      formData['csrfmiddlewaretoken'] = csrfToken;
      debugPrint('🔐 Added CSRF token to form data');
    }
    
    // Convert form data to URL-encoded string
    final formBody = formData.entries.map((e) => 
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}'
    ).join('&');
    
    debugPrint('📤 Encoded form body: $formBody');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: formBody,
      );
      
      debugPrint('📊 Form response status: ${response.statusCode}');
      debugPrint('📋 Form response headers: ${response.headers}');
      
      return response;
    } catch (e) {
      debugPrint('❌ Form request error: $e');
      rethrow;
    }
  }

  /// Make authenticated API request with CSRF handling for POST requests
  Future<http.Response> authenticatedRequest({
    required String endpoint,
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    // Check if authenticated
    if (!await isAuthenticated()) {
      // Try to re-authenticate
      final authResult = await authenticate();
      if (!authResult.success) {
        throw Exception('Authentication required: ${authResult.message}');
      }
    }
    
    final url = endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint';
    
    // For POST requests, use CSRF token strategy
    if (method.toUpperCase() == 'POST') {
      return await _postWithCsrfToken(url, body, additionalHeaders);
    }
    
    // For non-POST requests, use regular headers
    final headers = await getAuthHeaders();
    
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    try {
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: headers);
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Detect server-side session expiry: Django redirects to /login/ or returns HTML
      if (_isSessionExpiredResponse(response)) {
        debugPrint('🔄 AuthService: server-side session expired detected on $method $url');
        debugPrint('🔄 AuthService: attempting re-authentication...');
        final authResult = await authenticate();
        if (authResult.success) {
          debugPrint('✅ AuthService: re-auth successful, retrying request');
          final freshHeaders = await getAuthHeaders();
          if (additionalHeaders != null) freshHeaders.addAll(additionalHeaders);
          switch (method.toUpperCase()) {
            case 'GET':
              response = await http.get(Uri.parse(url), headers: freshHeaders);
              break;
            case 'PUT':
              response = await http.put(Uri.parse(url), headers: freshHeaders,
                  body: body != null ? jsonEncode(body) : null);
              break;
            case 'DELETE':
              response = await http.delete(Uri.parse(url), headers: freshHeaders);
              break;
          }
          debugPrint('📊 AuthService: retry response status=${response.statusCode}');
        } else {
          debugPrint('❌ AuthService: re-auth failed: ${authResult.message}');
        }
      }

      // Check for 401 Unauthorized
      if (response.statusCode == 401) {
        debugPrint('🚨 401 Unauthorized detected - redirecting to login');
        await _handle401Unauthorized();
      }

      return response;
    } catch (e) {
      debugPrint('❌ Authenticated request error: $e');
      rethrow;
    }
  }

  /// POST request with CSRF token in headers (the working strategy)
  Future<http.Response> _postWithCsrfToken(
    String url, 
    Map<String, dynamic>? body, 
    Map<String, String>? additionalHeaders
  ) async {
    debugPrint('📝 POST with CSRF token in headers');
    
    // Fetch fresh CSRF token before POST request
    debugPrint('🔄 Fetching fresh CSRF token for POST request...');
    final sessionInfo = await getSessionInfo();
    String? csrfToken;
    
    if (sessionInfo != null && sessionInfo['csrf_token'] != null) {
      csrfToken = sessionInfo['csrf_token'];
      debugPrint('✅ Got fresh CSRF token: ${csrfToken!.substring(0, 8)}...');
    } else {
      // Fallback to stored token if fresh fetch fails
      debugPrint('⚠️ Failed to get fresh CSRF token, using stored one');
      csrfToken = await getStoredCsrfToken();
    }
    
    final headers = await getAuthHeadersWithCsrf();
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    // Add CSRF token to body as well (some Django configs expect it)
    if (body != null && csrfToken != null && csrfToken.isNotEmpty) {
      body['csrfmiddlewaretoken'] = csrfToken;
      debugPrint('🔐 Added CSRF token to request body as well');
    }
    
    // Check if we should send as form-encoded data (for Django forms)
    final shouldUseFormEncoding = url.contains('/ess/od-application/') || 
                                  url.contains('/ess/application-approval/') ||
                                  url.contains('/ess/leave-application/') ||
                                  url.contains('/ess/comp-off-application/') ||
                                  url.contains('/ess/compoff-application/') ||
                                  url.contains('/ess/miss-punch/') ||
                                  url.contains('/ess/payslip-generate/') ||
                                  url.contains('/visitors/employee-screen/');
    
    http.Response response;
    
    if (shouldUseFormEncoding && body != null) {
      debugPrint('📝 Sending as form-encoded data');
      // Convert body to form-encoded string
      final formData = body.entries.map((e) => 
        '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}'
      ).join('&');
      
      // Update headers for form encoding
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      
      debugPrint('📤 Form data: $formData');
      
      response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: formData,
      );
    } else {
      debugPrint('📝 Sending as JSON data');
      response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );
    }
    
    debugPrint('📊 POST response: ${response.statusCode}');
    debugPrint('📋 POST headers: ${response.headers}');
    
    // Handle redirects - Django typically redirects after successful POST
    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      debugPrint('🔄 Redirect detected to: $location');
      
      // Check for Django messages in cookies to determine success/error
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.contains('messages=')) {
        debugPrint('📨 Server returned message in redirect');
        
        // Decode the message to check if it's success or error
        // Django message format: messages=<base64>; ...
        // Success messages typically have level 25 (SUCCESS), errors have level 40 (ERROR)
        try {
          final messagesMatch = RegExp(r'messages=([^;]+)').firstMatch(setCookie);
          if (messagesMatch != null) {
            final messageData = messagesMatch.group(1);
            debugPrint('📨 Message data: $messageData');
            
            // If message contains success indicators, treat as success
            // Common success patterns: "successfully", "saved", "submitted", "approved", "rejected"
            final decodedMessage = Uri.decodeComponent(messageData ?? '');
            if (decodedMessage.toLowerCase().contains('success') ||
                decodedMessage.toLowerCase().contains('approved') ||
                decodedMessage.toLowerCase().contains('rejected') ||
                decodedMessage.toLowerCase().contains('saved')) {
              debugPrint('✅ Success message detected in redirect');
              // Return a synthetic 200 response to indicate success
              return http.Response('{"success": true, "message": "Operation completed successfully"}', 200);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing message: $e');
        }
        
        // If we can't determine, follow the redirect
        debugPrint('🔄 Following redirect to check result');
      }
      
      if (location != null) {
        final redirectResponse = await _followRedirect(location, headers);
        if (redirectResponse != null) {
          debugPrint('✅ POST successful after redirect');
          return redirectResponse;
        }
      }
    }
    
    debugPrint('✅ POST successful');
    return response;
  }

  /// Check response for 401 and handle accordingly
  static Future<void> checkAndHandle401(http.Response response) async {
    if (response.statusCode == 401) {
      debugPrint('🚨 401 Unauthorized detected in response');
      final authService = AuthService();
      await authService._handle401Unauthorized();
    }
  }

  /// Handle 401 Unauthorized - clear session and trigger redirect
  Future<void> _handle401Unauthorized() async {
    debugPrint('🔐 Handling 401 Unauthorized error');
    
    // Clear authentication data
    await clearAuth();
    
    // Trigger the callback to redirect to login
    if (onUnauthorized != null) {
      debugPrint('🔄 Triggering onUnauthorized callback');
      onUnauthorized!();
    } else {
      debugPrint('⚠️ No onUnauthorized callback registered');
    }
  }

  /// Detect if a response indicates the server-side session has expired.
  /// Django redirects to /login/ (302) or returns an HTML login page (200 with HTML).
  bool _isSessionExpiredResponse(http.Response response) {
    // 302 redirect to login page
    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'] ?? '';
      if (location.contains('/login') || location.contains('/app-login')) {
        debugPrint('🔐 AuthService: session expired — redirect to $location');
        return true;
      }
    }
    // 403 Forbidden
    if (response.statusCode == 403) {
      debugPrint('🔐 AuthService: session expired — 403 Forbidden');
      return true;
    }
    // 200 but HTML body (Django login page returned instead of JSON)
    if (response.statusCode == 200) {
      final ct = response.headers['content-type'] ?? '';
      final body = response.body.trim();
      if (ct.contains('text/html') && (body.startsWith('<!DOCTYPE') || body.startsWith('<html'))) {
        debugPrint('🔐 AuthService: session expired — got HTML instead of JSON');
        return true;
      }
    }
    return false;
  }

  /// Follow a redirect and return the final response
  Future<http.Response?> _followRedirect(String location, Map<String, String> headers) async {
    try {
      debugPrint('🔄 Following redirect to: $location');
      
      // Make the location absolute if it's relative
      final redirectUrl = location.startsWith('http') ? location : '$_baseUrl$location';
      
      final redirectResponse = await http.get(
        Uri.parse(redirectUrl),
        headers: headers,
      );
      
      debugPrint('📊 Redirect response: ${redirectResponse.statusCode}');
      // Note: Redirect body logging removed to reduce terminal noise
      
      // Check if the redirect indicates success
      if (redirectResponse.statusCode == 200) {
        // Check if the response body contains success indicators
        final body = redirectResponse.body.toLowerCase();
        if (body.contains('success') || body.contains('submitted') || body.contains('saved')) {
          debugPrint('✅ Redirect indicates success');
          return redirectResponse;
        }
      }
      
      return redirectResponse;
    } catch (e) {
      debugPrint('❌ Error following redirect: $e');
      return null;
    }
  }
  
  /// Get user information from stored preferences
  Future<UserInfo?> getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final userId = prefs.getString('user_id');
      final userName = prefs.getString('user_name');
      final username = prefs.getString('username');
      
      if (email == null) return null;
      
      return UserInfo(
        email: email,
        userId: userId,
        userName: userName,
        username: username,
      );
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return null;
    }
  }
  
  /// Clear authentication data (logout)
  Future<void> clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('login_time');
      await prefs.remove('session_cookies');
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('username');
      
      debugPrint('🚪 Authentication data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing auth data: $e');
    }
  }
  
  /// Get employee paycode for API requests
  Future<String?> getEmployeePaycode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try to get username first, then user_id as fallback
      return prefs.getString('user_email') ?? prefs.getString('user_id');
    } catch (e) {
      debugPrint('❌ Error getting employee paycode: $e');
      return null;
    }
  }

  /// Get the numeric emp_code (e.g. 1690) from checkin_checkout data saved at login
  Future<String?> getEmpPaycode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First try the directly saved numeric emp_code
      final savedEmpCode = prefs.getString('numeric_emp_code');
      if (savedEmpCode != null && savedEmpCode.isNotEmpty) {
        debugPrint('✅ Got numeric emp_code from SharedPreferences: $savedEmpCode');
        return savedEmpCode;
      }
      
      // Fall back: parse emp_code from the saved checkin_checkout_data
      final checkInOutJson = prefs.getString('checkin_checkout_data');
      if (checkInOutJson != null && checkInOutJson.isNotEmpty) {
        try {
          final checkInOutData = jsonDecode(checkInOutJson);
          // Response format: {"data": [{"emp_code": 138, ...}], ...}
          final dataList = checkInOutData['data'];
          if (dataList != null && dataList is List && dataList.isNotEmpty) {
            final empCode = dataList[0]['emp_code']?.toString() ?? '';
            if (empCode.isNotEmpty && empCode != 'null') {
              debugPrint('✅ Got numeric emp_code from checkin_checkout_data: $empCode');
              await prefs.setString('numeric_emp_code', empCode);
              return empCode;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing checkin_checkout_data for emp_code: $e');
        }
      }
      
      debugPrint('⚠️ numeric emp_code not found, falling back to emp_paycode');
      return prefs.getString('emp_paycode') ?? prefs.getString('username');
    } catch (e) {
      debugPrint('❌ Error getting emp_code: $e');
      return null;
    }
  }
  
  /// Get employee profile data for form pre-filling
  Future<Map<String, dynamic>?> getEmployeeProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // emp_paycode is the actual employee code (e.g. S1010631)
      final empPaycode = prefs.getString('emp_paycode') ?? prefs.getString('username') ?? prefs.getString('user_email') ?? '';
      final userName = prefs.getString('user_name') ?? prefs.getString('username') ?? '';
      
      if (empPaycode.isEmpty) return null;
      
      return {
        'emp_code': empPaycode,
        'emp_name': userName,
        'email': prefs.getString('user_email') ?? '',
        'user_id': prefs.getString('user_id') ?? '',
      };
    } catch (e) {
      debugPrint('❌ Error getting employee profile: $e');
      return null;
    }
  }
}

/// Authentication result class
class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  
  AuthResult({
    required this.success,
    required this.message,
    this.data,
  });
}

/// User information class
class UserInfo {
  final String email;
  final String? userId;
  final String? userName;
  final String? username;
  
  UserInfo({
    required this.email,
    this.userId,
    this.userName,
    this.username,
  });
  
  @override
  String toString() {
    return 'UserInfo(email: $email, userId: $userId, userName: $userName, username: $username)';
  }
}
