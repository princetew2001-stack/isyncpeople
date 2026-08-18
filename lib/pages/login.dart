import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'home.dart';
import '../utils/dummy_data_service.dart';
import '../utils/forgotten_password_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  String _appVersion = '';
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;



  String _getCurrentDayOfWeek() {
    return DateFormat('EEEE').format(DateTime.now());
  }

  String _getCurrentDate() {
    return DateFormat('MMMM dd, yyyy').format(DateTime.now());
  }



  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAutoLogin();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  void _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final loginTimeStr = prefs.getString('login_time');
      
      if (isLoggedIn && loginTimeStr != null) {
        final loginTime = DateTime.parse(loginTimeStr);
        final currentTime = DateTime.now();
        final daysDifference = currentTime.difference(loginTime).inDays;
        
        // Check if login is still valid (within 30 days)
        if (daysDifference < 30) {
          // Auto login - navigate to home page
          // Ntfy listener will be started from home page to avoid duplicates
          debugPrint('🔔 Ntfy listener will be started from home page');
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
          return;
        } else {
          // Login expired - clear stored data
          await _clearLoginData();
        }
      }
      
      // Load saved credentials if available
      _loadSavedCredentials();
    } catch (e) {
      // Handle error silently
      debugPrint('Error checking auto login: $e');
    }
  }

  void _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use dedicated autofill keys that persist across logout
      final savedUsername = prefs.getString('autofill_username');
      final savedPassword = prefs.getString('autofill_password');

      if (savedUsername != null && savedUsername.isNotEmpty) {
        setState(() {
          _emailController.text = savedUsername;
          if (savedPassword != null && savedPassword.isNotEmpty) {
            _passwordController.text = savedPassword;
          }
        });
        debugPrint('✅ Autofill loaded for: $savedUsername');
      }
    } catch (e) {
      debugPrint('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveLoginData([Map<String, dynamic>? loginResponseData]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('login_time', DateTime.now().toIso8601String());
      await prefs.setString('user_email', _emailController.text.trim());

      // Always save credentials to autofill keys — these persist across logout
      // so the login screen can pre-fill them on next visit
      await prefs.setString('autofill_username', _emailController.text.trim());
      await prefs.setString('autofill_password', _passwordController.text.trim());
      debugPrint('💾 Autofill credentials saved for: ${_emailController.text.trim()}');
      
      // Save user data from login response if available
      if (loginResponseData != null) {
        // Save permissions if available
        if (loginResponseData.containsKey('permissions')) {
          final permissionsData = loginResponseData['permissions'];
          if (permissionsData != null && permissionsData is Map) {
            await prefs.setString('user_permissions', jsonEncode(permissionsData));
            debugPrint('💾 Saved user permissions');
            debugPrint('📋 Module: ${permissionsData['module']}');
            debugPrint('📋 Permissions count: ${(permissionsData['permissions'] as List?)?.length ?? 0}');
          }
        }
        
        // Save emp_paycode for ntfy topic
        // If not found in API response, use username as fallback
        String? empPaycode;
        if (loginResponseData.containsKey('emp_paycode')) {
          empPaycode = loginResponseData['emp_paycode']?.toString();
        } else if (loginResponseData.containsKey('paycode')) {
          empPaycode = loginResponseData['paycode']?.toString();
        } else if (loginResponseData.containsKey('pay_code')) {
          empPaycode = loginResponseData['pay_code']?.toString();
        }
        
        // Fallback to username if emp_paycode not found
        if (empPaycode == null || empPaycode.isEmpty) {
          empPaycode = _emailController.text.trim(); // Use username as fallback
          debugPrint('⚠️ emp_paycode not found in login response, using username as fallback: $empPaycode');
        } else {
          debugPrint('💾 Saved emp_paycode from API: $empPaycode');
        }
        
        // Always save emp_paycode (either from API or username fallback)
        await prefs.setString('emp_paycode', empPaycode);
        
        // Save user ID
        String? userId;
        if (loginResponseData.containsKey('user_id')) {
          userId = loginResponseData['user_id']?.toString();
        } else if (loginResponseData.containsKey('id')) {
          userId = loginResponseData['id']?.toString();
        } else if (loginResponseData.containsKey('userId')) {
          userId = loginResponseData['userId']?.toString();
        } else if (loginResponseData.containsKey('user') && loginResponseData['user'] is Map) {
          final userObj = loginResponseData['user'] as Map<String, dynamic>;
          if (userObj.containsKey('id')) {
            userId = userObj['id']?.toString();
          } else if (userObj.containsKey('user_id')) {
            userId = userObj['user_id']?.toString();
          }
        }
        
        if (userId != null) {
          await prefs.setString('user_id', userId);
          debugPrint('💾 Saved user ID: $userId');
        } else {
          debugPrint('⚠️ User ID not found in login response');
        }
        
        // Save user name
        String? userName;
        if (loginResponseData.containsKey('name')) {
          userName = loginResponseData['name']?.toString();
        } else if (loginResponseData.containsKey('user_name')) {
          userName = loginResponseData['user_name']?.toString();
        } else if (loginResponseData.containsKey('full_name')) {
          userName = loginResponseData['full_name']?.toString();
        } else if (loginResponseData.containsKey('user') && loginResponseData['user'] is Map) {
          final userObj = loginResponseData['user'] as Map<String, dynamic>;
          userName = userObj['name']?.toString() ?? userObj['user_name']?.toString() ?? userObj['full_name']?.toString();
        }
        
        if (userName != null) {
          await prefs.setString('user_name', userName);
          debugPrint('💾 Saved user name: $userName');
        } else {
          debugPrint('⚠️ User name not found in login response');
        }
        
        // Save username
        String? username;
        if (loginResponseData.containsKey('username')) {
          username = loginResponseData['username']?.toString();
        } else if (loginResponseData.containsKey('user') && loginResponseData['user'] is Map) {
          final userObj = loginResponseData['user'] as Map<String, dynamic>;
          username = userObj['username']?.toString();
        }
        
        if (username != null) {
          await prefs.setString('username', username);
          debugPrint('💾 Saved username: $username');
        } else {
          debugPrint('⚠️ Username not found in login response');
        }
        
        // Save punch data from login response
        if (loginResponseData.containsKey('punch_in_data')) {
          final punchInData = loginResponseData['punch_in_data'];
          if (punchInData != null && punchInData is Map && punchInData.isNotEmpty) {
            // User has already punched in
            await prefs.setString('punch_in_data', jsonEncode(punchInData));
            await prefs.setBool('is_clocked_in', true);
            
            // Parse punch in time and location
            if (punchInData.containsKey('punch_time')) {
              final punchTime = punchInData['punch_time']?.toString();
              if (punchTime != null) {
                await prefs.setString('check_in_time', punchTime);
                debugPrint('💾 Saved punch in time: $punchTime');
              }
            }
            
            if (punchInData.containsKey('punch_loc')) {
              final punchLoc = punchInData['punch_loc']?.toString();
              if (punchLoc != null) {
                await prefs.setString('check_in_location', punchLoc);
                debugPrint('💾 Saved punch in location: $punchLoc');
              }
            }
            
            debugPrint('💾 User already punched in - saved punch_in_data');
          } else {
            // No punch in data - clear any existing data
            await prefs.remove('punch_in_data');
            await prefs.setBool('is_clocked_in', false);
            await prefs.remove('check_in_time');
            await prefs.remove('check_in_location');
            debugPrint('💾 No punch in data - cleared existing data');
          }
        }
        
        if (loginResponseData.containsKey('punch_out_data')) {
          final punchOutData = loginResponseData['punch_out_data'];
          if (punchOutData != null && punchOutData is Map && punchOutData.isNotEmpty) {
            // User has already punched out
            await prefs.setString('punch_out_data', jsonEncode(punchOutData));
            await prefs.setBool('is_clocked_out', true);
            
            // Parse punch out time and location
            if (punchOutData.containsKey('punch_time')) {
              final punchTime = punchOutData['punch_time']?.toString();
              if (punchTime != null) {
                await prefs.setString('check_out_time', punchTime);
                debugPrint('💾 Saved punch out time: $punchTime');
              }
            }
            
            if (punchOutData.containsKey('punch_loc')) {
              final punchLoc = punchOutData['punch_loc']?.toString();
              if (punchLoc != null) {
                await prefs.setString('check_out_location', punchLoc);
                debugPrint('💾 Saved punch out location: $punchLoc');
              }
            }
            
            debugPrint('💾 User already punched out - saved punch_out_data');
          } else {
            // No punch out data - clear any existing data
            await prefs.remove('punch_out_data');
            await prefs.setBool('is_clocked_out', false);
            await prefs.remove('check_out_time');
            await prefs.remove('check_out_location');
            debugPrint('💾 No punch out data - cleared existing data');
          }
        }
      }
      
      // Only save password if remember me is checked
      if (_rememberMe) {
        await prefs.setString('user_password', _passwordController.text.trim());
      }
    } catch (e) {
      debugPrint('Error saving login data: $e');
    }
  }

  Future<void> _clearLoginData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('login_time');
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('username');
      await prefs.remove('emp_paycode');
      // Clear punch data
      await prefs.remove('punch_in_data');
      await prefs.remove('punch_out_data');
      await prefs.remove('is_clocked_in');
      await prefs.remove('is_clocked_out');
      await prefs.remove('check_in_time');
      await prefs.remove('check_in_location');
      await prefs.remove('check_out_time');
      await prefs.remove('check_out_location');
    } catch (e) {
      debugPrint('Error clearing login data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A1A),
                  Color(0xFF0D0D0D),
                ],
              ),
            ),
          ),
          
          // Floating golden circles
          _buildFloatingCircles(),

          // Version label - top right corner
          Positioned(
            top: 12,
            right: 16,
            child: SafeArea(
              child: Text(
                _appVersion,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Main content - Made scrollable
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // App Logo/Icon
                                Image.asset(
                                  'assets/images/intellisync.png',
                                  width: 180,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to Icon.png if intellisync.png fails to load
                                    return Image.asset(
                                      'assets/images/Icon.png',
                                      width: 180,
                                      height: 120,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Current Day
                                Text(
                                  _getCurrentDayOfWeek(),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Current Date
                                Text(
                                  _getCurrentDate(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Welcome Text
                                Text(
                                  'Welcome back!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                
                                const SizedBox(height: 40),
                                
                                // Username Field
                                _buildGlassInputField(
                                  controller: _emailController,
                                  hint: 'Username',
                                  validator: _validateUsername,
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Password Field
                                _buildGlassInputField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  isPassword: true,
                                  validator: _validatePassword,
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Remember Me
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                        fillColor: WidgetStateProperty.resolveWith((states) {
                                          if (states.contains(WidgetState.selected)) {
                                            return const Color(0xFFD4AF37);
                                          }
                                          return Colors.transparent;
                                        }),
                                        checkColor: Colors.black,
                                        side: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD4AF37),
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Log In',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Forgot Password - Outside container
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCircles() {
    return Stack(
      children: [
        // Top right circle
        Positioned(
          top: -50,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        
        // Bottom left circle
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  const Color(0xFFD4AF37).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        
        // Top left small circle
        Positioned(
          top: 100,
          left: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        
        // Bottom right circle
        Positioned(
          bottom: 150,
          right: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD4AF37).withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w300,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 16,
          fontWeight: FontWeight.w300,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFD4AF37),
            width: 2,
          ),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your username';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final username = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        // Call login API
        final response = await _loginAPI(username, password);
        
        if (response['success'] == true) {
          // Save login data for auto-login including user ID
          await _saveLoginData(response['data']);
          
          // Call check-in/check-out API after successful login
          await _fetchCheckInOutData(response['data']);
          
          // Start ntfy listener if emp_paycode is available
          // Ntfy listener will be started from home page to avoid duplicates
          debugPrint('🔔 Ntfy listener will be started from home page');
          
          // Successful login
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          // Failed login
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            _showErrorMessage('Invalid username or password');
          }
        }
      } catch (e) {
        // Network or other error - try fallback login for testing
        debugPrint('❌ API Login failed: $e');
        
        // Fallback to hardcoded credentials for testing
        if (username == DummyDataService.testUsername && password == DummyDataService.testPassword) {
          debugPrint('🧪 Using test user credentials - initializing dummy data');
          
          // Initialize comprehensive dummy data for test user
          await DummyDataService.initializeDummyData();
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          
          if (mounted) {
            final err = e.toString();
            if (err.contains('timeout') || err.contains('Connection timeout')) {
              _showErrorMessage('Something went wrong. Please check your connection and try again.');
            } else {
              _showErrorMessage('Something went wrong. Please try again.');
            }
          }
        }
      }
    }
  }

  Future<void> _fetchCheckInOutData(Map<String, dynamic> loginData) async {
    try {
      // Get username from login response for emp_paycode
      String? empPaycode;
      if (loginData.containsKey('username')) {
        empPaycode = loginData['username']?.toString();
      } else if (loginData.containsKey('user')) {
        final userObj = loginData['user'] as Map<String, dynamic>?;
        empPaycode = userObj?['username']?.toString();
      }
      
      // Fallback to the entered username if not found in response
      empPaycode ??= _emailController.text.trim();
      
      // Get current year and month
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      
      final checkInOutUrl = 'https://delton.intellisync.in:11004/checkin_checkout/?emp_paycode=$empPaycode&year=$currentYear&month=$currentMonth';
      
      debugPrint('🔗 Fetching check-in/check-out data from: $checkInOutUrl');
      debugPrint('📋 Parameters: emp_paycode=$empPaycode, year=$currentYear, month=$currentMonth');
      
      final response = await http.get(
        Uri.parse(checkInOutUrl),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Check-in/out API timeout after 10 seconds');
          throw Exception('Check-in/out API timeout');
        },
      );

      debugPrint('✅ Check-in/out API Response received');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📋 Response Headers: ${response.headers}');
      debugPrint('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          debugPrint('🔍 Check-in/out data parsed successfully');
          debugPrint('📊 Data: $responseData');
          
          // Parse attendance data from the response
          if (responseData['data'] != null && responseData['data'] is List && responseData['data'].isNotEmpty) {
            final attendanceData = responseData['data'][0]; // Get first employee data
            
            // Extract attendance values
            final workingDays = attendanceData['working_days']?.toString() ?? '0';
            final absentDays = attendanceData['absent_days']?.toString() ?? '0';
            final holidays = attendanceData['holidays']?.toString() ?? '0';
            final weekOffs = attendanceData['week_offs']?.toString() ?? '0';
            
            // Extract leave data
            final elUsed = attendanceData['el_used']?.toString() ?? '0';
            final slUsed = attendanceData['sl_used']?.toString() ?? '0';
            final clUsed = attendanceData['cl_used']?.toString() ?? '0';
            
            // Calculate total leave
            final totalLeave = (int.tryParse(elUsed) ?? 0) + 
                              (int.tryParse(slUsed) ?? 0) + 
                              (int.tryParse(clUsed) ?? 0);
            
            debugPrint('📊 Parsed attendance data:');
            debugPrint('   Working Days: $workingDays');
            debugPrint('   Absent Days: $absentDays');
            debugPrint('   Holidays: $holidays');
            debugPrint('   Week Offs: $weekOffs');
            debugPrint('📊 Parsed leave data:');
            debugPrint('   EL Used: $elUsed');
            debugPrint('   SL Used: $slUsed');
            debugPrint('   CL Used: $clUsed');
            debugPrint('   Total Leave: $totalLeave');
            
            // Save attendance data to SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('attendance_working_days', workingDays);
            await prefs.setString('attendance_absent_days', absentDays);
            await prefs.setString('attendance_holidays', holidays);
            await prefs.setString('attendance_week_offs', weekOffs);
            
            // Save leave data to SharedPreferences
            await prefs.setString('leave_el_used', elUsed);
            await prefs.setString('leave_sl_used', slUsed);
            await prefs.setString('leave_cl_used', clUsed);
            await prefs.setString('leave_total', totalLeave.toString());
            
            // Also save the complete response for future use
            await prefs.setString('checkin_checkout_data', jsonEncode(responseData));
            
            // Save numeric emp_code for use in APIs like miss-punch-dates
            final numericEmpCode = attendanceData['emp_code']?.toString() ?? '';
            if (numericEmpCode.isNotEmpty) {
              await prefs.setString('numeric_emp_code', numericEmpCode);
              debugPrint('💾 Saved numeric emp_code: $numericEmpCode');
            }
            
            debugPrint('💾 Attendance and leave data saved to local storage');
          } else {
            debugPrint('⚠️ No attendance data found in response');
          }
          
        } catch (jsonError) {
          debugPrint('❌ JSON parsing error for check-in/out data: $jsonError');
        }
      } else {
        debugPrint('❌ Check-in/out API error: Status ${response.statusCode}');
        debugPrint('📄 Error response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching check-in/out data: $e');
      // Don't throw error here as it shouldn't prevent login
    }
  }

  Future<Map<String, dynamic>> _loginAPI(String username, String password) async {
    const String apiUrl = 'https://delton.intellisync.in:11004/app-login/';
    
    debugPrint('🔗 Attempting to connect to: $apiUrl');
    debugPrint('📤 Request payload: {"username": "$username", "password": "***"}');
    
    try {
      
      debugPrint(' testinggggggggggggggggggg network connectivity...');
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint(' Request timed out after 15 seconds');
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
          
          // Check various success indicators
          bool isSuccess = false;
          
          if (responseData.containsKey('success')) {
            isSuccess = responseData['success'] == true;
          } else if (responseData.containsKey('status')) {
            // Handle both boolean and string status values
            final status = responseData['status'];
            isSuccess = status == true || 
                       status == 'success' || 
                       status == 'ok' ||
                       status == 200;
          } else if (responseData.containsKey('error')) {
            isSuccess = responseData['error'] == null || responseData['error'] == false;
          } else {
            // If no clear success indicator, assume success for 200 status
            isSuccess = true;
          }
          
          debugPrint('🔍 Success check: status=${responseData['status']}, isSuccess=$isSuccess');
          
          if (isSuccess) {
            debugPrint('✅ Login successful');
            
            // Store session cookies for future API calls
            final cookies = response.headers['set-cookie'];
            if (cookies != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('session_cookies', cookies);
              debugPrint('🍪 Session cookies stored: $cookies');
            }
            
            return {
              'success': true,
              'data': responseData,
            };
          } else {
            debugPrint('❌ Login failed - Invalid credentials');
            return {
              'success': false,
              'error': responseData['message'] ?? responseData['error'] ?? 'Invalid credentials',
            };
          }
        } catch (jsonError) {
          debugPrint('❌ JSON parsing error: $jsonError');
          debugPrint('Raw response: ${response.body}');
          return {
            'success': false,
            'error': 'Invalid server response format',
          };
        }
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized (401) - Invalid credentials');
        return {
          'success': false,
          'error': 'Invalid username or password',
        };
      } else if (response.statusCode == 404) {
        debugPrint('❌ Not Found (404) - API endpoint not found');
        return {
          'success': false,
          'error': 'Login service not available',
        };
      } else if (response.statusCode >= 500) {
        debugPrint('❌ Server Error (${response.statusCode})');
        return {
          'success': false,
          'error': 'Server error. Please try again later.',
        };
      } else {
        debugPrint('❌ Unexpected status code: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Unexpected server response (${response.statusCode})',
        };
      }
    } on http.ClientException catch (e) {
      debugPrint('🌐 Network Error (ClientException): $e');
      throw Exception('Network error: Unable to connect to server. Please check your internet connection.');
    } on FormatException catch (e) {
      debugPrint('📄 Format Error: $e');
      throw Exception('Server response format error');
    } on Exception catch (e) {
      debugPrint('❌ General Exception: $e');
      if (e.toString().contains('timeout') || e.toString().contains('Connection timeout')) {
        throw Exception('Connection timeout: Server is taking too long to respond. Please try again.');
      } else {
        throw Exception('Network error: ${e.toString()}');
      }
    } catch (e) {
      debugPrint('❌ Unknown Error: $e');
      throw Exception('Unexpected error occurred. Please try again.');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }


}


// Forgot Password Page
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  int _currentStep = 0; // 0: Username, 1: Verify OTP, 2: Change Password
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the forgotten password API
      final response = await ForgottenPasswordAPI.sendOTP(_usernameController.text.trim());

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        // OTP sent successfully, move to next step
        setState(() {
          _currentStep = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'OTP sent to your registered email/phone')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Failed to send OTP
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'Failed to send OTP')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Please enter OTP')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the verify OTP API with username
      final response = await ForgottenPasswordAPI.verifyOTP(
        _usernameController.text.trim(),
        _otpController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        // OTP verified successfully, move to next step
        setState(() {
          _currentStep = 2;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'OTP verified successfully')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Failed to verify OTP
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'Invalid or expired OTP')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _changePassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Please fill all fields')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Passwords do not match')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Password must be at least 6 characters')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the reset password API with username
      final response = await ForgottenPasswordAPI.resetPassword(
        _usernameController.text.trim(),
        _newPasswordController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (response['success'] == true) {
        // Password reset successfully
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'Password changed successfully')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          
          // Navigate back to login after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      } else {
        // Failed to reset password
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(response['message'] ?? 'Failed to reset password')),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Logo
              Image.asset(
                'assets/images/intellisync.png',
                width: 200,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/Icon.png',
                    width: 200,
                    height: 120,
                    fit: BoxFit.contain,
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Main Card - Extended form container
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                            // Title
                            const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _currentStep == 0
                                  ? 'Verify with OTP and set new password'
                                  : _currentStep == 1
                                      ? 'Enter the OTP sent to your email/phone'
                                      : 'Set your new password',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Step 1: Username
                            if (_currentStep == 0) ...[
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  hintText: 'Enter your username',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter username';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _sendOTP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Send OTP',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                            
                            // Step 2: Verify OTP
                            if (_currentStep == 1) ...[
                              TextFormField(
                                controller: _otpController,
                                decoration: InputDecoration(
                                  labelText: 'OTP',
                                  hintText: 'Enter 6-digit OTP',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOTP,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Verify OTP',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                            
                            // Step 3: Change Password
                            if (_currentStep == 2) ...[
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  hintText: 'Enter new password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_isConfirmPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  hintText: 'Re-enter new password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isConfirmPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Change Password',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Back to Login
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Steps Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator(0, 'Username'),
                  _buildStepLine(0),
                  _buildStepIndicator(1, 'Verify OTP'),
                  _buildStepLine(1),
                  _buildStepIndicator(2, 'Change Password'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blue : Colors.grey[300],
            border: Border.all(
              color: isCurrent ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey[600],
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    
    return Container(
      width: 60,
      height: 2,
      margin: const EdgeInsets.only(bottom: 30),
      color: isActive ? Colors.blue : Colors.grey[300],
    );
  }
}
