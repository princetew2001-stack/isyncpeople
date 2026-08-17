import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import '../utils/notification_service.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final location = await Permission.location.status;
    final notification = await Permission.notification.status;
    
    setState(() {
      _locationGranted = location.isGranted;
      _notificationGranted = notification.isGranted;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);

    await Permission.location.request();
    await Permission.notification.request();
    
    await NotificationService.requestPermissions();
    
    await _checkPermissions();
    
    if (_locationGranted && _notificationGranted) {
      await _navigateToLogin();
    }
    
    setState(() => _isRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD2691E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(
                Icons.security,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To provide the best attendance tracking experience, we need access to:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildPermissionItem(
                Icons.location_on,
                'Location',
                'Track your check-in/check-out location',
                _locationGranted,
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                Icons.notifications,
                'Notifications',
                'Receive attendance reminders',
                _notificationGranted,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : () {
                    if (_locationGranted && _notificationGranted) {
                      _navigateToLogin();
                    } else {
                      _requestPermissions();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isRequesting
                      ? const CircularProgressIndicator(color: Color(0xFFD2691E))
                      : Text(
                          _getButtonText(),
                          style: const TextStyle(
                            color: Color(0xFFD2691E),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  String _getButtonText() {
    final grantedCount = [_locationGranted, _notificationGranted].where((g) => g).length;
    
    if (grantedCount == 2) {
      return 'Continue to App';
    } else if (grantedCount == 0) {
      return 'Grant All Permissions';
    } else {
      return 'Grant Remaining Permissions ($grantedCount/2)';
    }
  }

  Widget _buildPermissionItem(IconData icon, String title, String description, bool granted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: granted ? Colors.green : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (granted)
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
        ],
      ),
    );
  }
}