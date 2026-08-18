// Example of how to use AuthService in your other UI pages

import 'package:flutter/material.dart';
import 'dart:convert';
import 'auth_service.dart';

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final AuthService _authService = AuthService();
  bool isLoading = false;
  String? data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Example 1: Simple authenticated GET request
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await _authService.authenticatedRequest(
        endpoint: '/your-api-endpoint/',
        method: 'GET',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        setState(() {
          data = responseData.toString();
        });
      } else {
        _showError('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Example 2: POST request with body
  Future<void> _submitData(Map<String, dynamic> formData) async {
    try {
      final response = await _authService.authenticatedRequest(
        endpoint: '/submit-data/',
        method: 'POST',
        body: formData,
      );

      if (response.statusCode == 200) {
        _showSuccess('Data submitted successfully');
      } else {
        _showError('Failed to submit data');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }
  }

  // Example 3: Check authentication status
  Future<void> _checkAuth() async {
    final isAuth = await _authService.isAuthenticated();
    if (!isAuth) {
      // Redirect to login or show login dialog
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // Example 4: Get user information
  Future<void> _loadUserInfo() async {
    final userInfo = await _authService.getUserInfo();
    if (userInfo != null) {
      print('User: ${userInfo.userName} (${userInfo.email})');
    }
  }

  // Example 5: Logout
  Future<void> _logout() async {
    await _authService.clearAuth();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data ?? 'No data loaded'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Reload Data'),
                  ),
                  ElevatedButton(
                    onPressed: () => _submitData({'test': 'data'}),
                    child: const Text('Submit Test Data'),
                  ),
                  ElevatedButton(
                    onPressed: _checkAuth,
                    child: const Text('Check Auth'),
                  ),
                  ElevatedButton(
                    onPressed: _loadUserInfo,
                    child: const Text('Load User Info'),
                  ),
                ],
              ),
      ),
    );
  }
}

/*
USAGE EXAMPLES:

1. Simple GET request:
   final response = await _authService.authenticatedRequest(
     endpoint: '/api/data',
   );

2. POST request with data:
   final response = await _authService.authenticatedRequest(
     endpoint: '/api/submit',
     method: 'POST',
     body: {'key': 'value'},
   );

3. Check if user is authenticated:
   final isAuth = await _authService.isAuthenticated();

4. Get user info:
   final userInfo = await _authService.getUserInfo();

5. Get employee paycode:
   final paycode = await _authService.getEmployeePaycode();

6. Logout:
   await _authService.clearAuth();

7. Manual authentication:
   final result = await _authService.authenticate(
     username: 'user',
     password: 'pass',
   );

The AuthService automatically handles:
- Session management
- Cookie storage and retrieval
- Re-authentication when session expires
- Error handling for 401 responses
- Consistent headers for all requests
*/