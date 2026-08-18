import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

/// Background service that keeps ntfy listener running even when app is closed
class NtfyBackgroundService {
  static String? _cachedEmpPaycode; // Cache the emp_paycode for background use
  
  /// Initialize and start the foreground service
  static Future<void> initialize() async {
    // Initialize foreground task
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ntfy_service',
        channelName: 'Ntfy Listener Service',
        channelDescription: 'Keeps notification listener running in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Check every 5 seconds
        autoRunOnBoot: true, // Auto-start on device boot
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    
    // Set up receiver for messages from background isolate
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }
  
  /// Handle data received from background isolate
  static void _onReceiveTaskData(dynamic data) {
    if (data is Map && data['action'] == 'showNotification') {
      final title = data['title'] as String?;
      final message = data['message'] as String?;
      
      if (title != null && message != null) {
        // Import notification service at the top and use it here
        NotificationService.showMotivationalNotification(title, message);
      }
    }
  }
  
  /// Start the foreground service
  static Future<bool> start() async {
    // Check if service is already running
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning) {
      print('🔔 Ntfy background service is already running');
      return true;
    }
    
    // Get emp_paycode from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String? empPaycode = prefs.getString('emp_paycode');
    
    if (empPaycode == null || empPaycode.isEmpty) {
      empPaycode = prefs.getString('username');
    }
    
    if (empPaycode == null || empPaycode.isEmpty) {
      empPaycode = prefs.getString('user_email');
    }
    
    if (empPaycode == null || empPaycode.isEmpty) {
      print('❌ No emp_paycode found to start background service');
      return false;
    }
    
    print('🚀 Starting ntfy background service for: $empPaycode');
    
    // Cache the emp_paycode for background isolate use
    _cachedEmpPaycode = empPaycode;
    
    // Store emp_paycode in a way that background isolate can access it
    await prefs.setString('background_emp_paycode', empPaycode);
    
    // Start the foreground service
    await FlutterForegroundTask.startService(
      notificationTitle: 'Visitor Notifications Active',
      notificationText: 'Connecting to notification server...',
      callback: startCallback,
    );
    
    print('✅ Ntfy background service started successfully');
    return true;
  }
  
  /// Stop the foreground service
  static Future<bool> stop() async {
    print('🛑 Stopping ntfy background service');
    
    // Remove the callback
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    
    await FlutterForegroundTask.stopService();
    return true;
  }
  
  /// Check if service is running
  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
  
  /// Get debug information about the service
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final isRunning = await FlutterForegroundTask.isRunningService;
    
    return {
      'isServiceRunning': isRunning,
      'cachedEmpPaycode': _cachedEmpPaycode,
      'empPaycode': prefs.getString('background_emp_paycode'),
      'fallbackEmpPaycode': prefs.getString('emp_paycode'),
      'username': prefs.getString('username'),
      'userEmail': prefs.getString('user_email'),
    };
  }
}

/// Callback function that runs in the background
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(NtfyTaskHandler());
}

/// Task handler that runs in the background isolate
class NtfyTaskHandler extends TaskHandler {
  http.Client? _client;
  StreamSubscription? _subscription;
  String? _empPaycode;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('🔔 Ntfy background task started');
    
    // Try multiple ways to get emp_paycode
    try {
      final prefs = await SharedPreferences.getInstance();
      _empPaycode = prefs.getString('background_emp_paycode') ?? 
                    prefs.getString('emp_paycode') ?? 
                    prefs.getString('username') ?? 
                    prefs.getString('user_email');
      
      print('📋 Background task emp_paycode sources:');
      print('   background_emp_paycode: ${prefs.getString('background_emp_paycode')}');
      print('   emp_paycode: ${prefs.getString('emp_paycode')}');
      print('   username: ${prefs.getString('username')}');
      print('   user_email: ${prefs.getString('user_email')}');
      print('   Selected: $_empPaycode');
      
    } catch (e) {
      print('❌ Error accessing SharedPreferences in background: $e');
    }
    
    if (_empPaycode == null || _empPaycode!.isEmpty) {
      print('❌ No emp_paycode found in background task');
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Visitor Notifications',
        notificationText: 'Error: No employee ID found',
      );
      return;
    }
    
    print('📡 Connecting to ntfy for: $_empPaycode');
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Visitor Notifications',
      notificationText: 'Connecting to server...',
    );
    await _connectToNtfy();
  }
  
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Check if connection is still alive, reconnect if needed
    if (_subscription == null || _client == null) {
      print('🔄 Reconnecting to ntfy...');
      FlutterForegroundTask.updateService(
        notificationTitle: 'Visitor Notifications',
        notificationText: 'Reconnecting to server...',
      );
      _connectToNtfy();
    } else {
      // Connection is alive, update status
      FlutterForegroundTask.updateService(
        notificationTitle: 'Visitor Notifications Active',
        notificationText: 'Connected and listening for visitors',
      );
    }
  }
  
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('🛑 Ntfy background task destroyed');
    await _subscription?.cancel();
    _client?.close();
  }
  
  Future<void> _connectToNtfy() async {
    try {
      // Clean up existing connections
      _cleanup();
      
      // Use the new URL format
      final urlString = 'http://115.124.102.153:8081/$_empPaycode/sse';
      final uri = Uri.parse(urlString);
      print('🔗 Background task connecting to ntfy URL: $uri');
      
      try {
        _client = http.Client();
        final request = http.Request('GET', uri);
        request.headers['Accept'] = 'text/event-stream';
        request.headers['Cache-Control'] = 'no-cache';
        request.headers['Connection'] = 'keep-alive';
        request.headers['User-Agent'] = 'Flutter-Background/1.0';
        
        print('📋 Background request headers: ${request.headers}');
        
        final response = await _client!.send(request).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏰ Background connection timeout for URL: $urlString');
            throw TimeoutException('Connection timeout', const Duration(seconds: 15));
          },
        );
        print('✅ Background connected to ntfy! Status: ${response.statusCode}');
        print('📋 Background response headers: ${response.headers}');
        
        // Check for rate limiting (HTTP 429)
        if (response.statusCode == 429) {
          print('❌ Background task rate limited! Too many active subscriptions');
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Visitor Notifications',
            notificationText: 'Rate limited - retrying in 60s',
          );
          
          // Wait and retry
          await Future.delayed(const Duration(seconds: 60));
          return _connectToNtfy(); // Retry
        }
        
        // Check if we're getting HTML instead of SSE
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          print('❌ Background received HTML instead of SSE! Content-Type: $contentType');
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Visitor Notifications',
            notificationText: 'Server error - retrying in 30s',
          );
          
          // Wait and retry
          await Future.delayed(const Duration(seconds: 30));
          return _connectToNtfy(); // Retry
        }

        // Success! Start listening to the stream
        print('🎉 Background successfully connected to ntfy SSE endpoint!');
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Visitor Notifications Active',
          notificationText: 'Connected and listening for visitors',
        );
        
        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) async {
          print('📥 Background received SSE line: $line');

          if (line.startsWith('data:')) {
            final jsonString = line.replaceFirst('data:', '').trim();
            if (jsonString.isEmpty) return;
            
            try {
              final data = json.decode(jsonString);
              print('📦 Background parsed SSE data: $data');
              
              if (data['event'] == 'message') {
                print('📨 Background received message: ${data['message']}');
                
                // Simple notification format
                await FlutterForegroundTask.updateService(
                  notificationTitle: 'New Visitor',
                  notificationText: data['message'] ?? 'Someone wants to meet you',
                );
                
                await _showNotification(
                  'New Visitor',
                  data['message'] ?? 'Someone wants to meet you',
                );
              } else if (data['event'] == 'keep-alive' || data['event'] == 'keepalive') {
                // Ignore keep-alive events - don't show notification
                print('💓 Background keep-alive event received - ignoring');
                return;
              }
            } catch (e) {
              print('⚠️ Background error parsing SSE message: $e');
              
              // If JSON parsing fails, treat as simple text message
              if (jsonString.isNotEmpty && 
                  !jsonString.contains('keep-alive') && 
                  !jsonString.contains('keepalive')) {
                print('📨 Background treating as simple text message: $jsonString');
                await FlutterForegroundTask.updateService(
                  notificationTitle: 'New Visitor',
                  notificationText: jsonString,
                );
                
                await _showNotification('New Visitor', jsonString);
              }
            }
          } else if (line.isNotEmpty && 
                     !line.startsWith(':') && 
                     !line.contains('keep-alive') && 
                     !line.contains('keepalive') &&
                     !line.startsWith('event:')) {
            // Handle direct text messages (non-JSON) but ignore keep-alive and SSE events
            print('📨 Background received direct message: $line');
            await FlutterForegroundTask.updateService(
              notificationTitle: 'New Visitor',
              notificationText: line,
            );
            
            await _showNotification('New Visitor', line);
          } else if (line.startsWith('event:')) {
            // Handle SSE event lines
            print('🔄 Background SSE event received: $line');
            if (line.contains('keepalive') || line.contains('keep-alive')) {
              print('💓 Background keep-alive event - ignoring');
            }
            // Don't show notifications for any event: lines
            return;
          }
        }, onError: (e) {
          print('❌ Background stream error: $e');
          FlutterForegroundTask.updateService(
            notificationTitle: 'Visitor Notifications',
            notificationText: 'Connection error - reconnecting...',
          );
          _cleanup();
        }, onDone: () {
          print('⚠️ Background stream closed, will reconnect...');
          FlutterForegroundTask.updateService(
            notificationTitle: 'Visitor Notifications',
            notificationText: 'Reconnecting to server...',
          );
          _cleanup();
        });

      } catch (e) {
        print('❌ Background error connecting: $e');
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Visitor Notifications',
          notificationText: 'Connection failed - will retry',
        );
        _cleanup();
        
        // Wait and retry
        await Future.delayed(const Duration(seconds: 30));
        return _connectToNtfy(); // Retry
      }
    } catch (e) {
      print('❌ Background error in _connectToNtfy: $e');
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Visitor Notifications',
        notificationText: 'Error connecting - will retry',
      );
    }
  }
  
  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
  
  Future<void> _showNotification(String title, String message) async {
    // Show notification using flutter_local_notifications directly in background
    print('🔔 Showing notification: $title - $message');
    
    try {
      // Create a notification plugin instance for background use
      final FlutterLocalNotificationsPlugin notificationsPlugin = 
          FlutterLocalNotificationsPlugin();
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'visitor_notifications',
        'Visitor Notifications',
        channelDescription: 'Notifications for visitor arrivals',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      );
      
      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      await notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        notificationDetails,
      );
      
      print('✅ Background notification shown successfully');
    } catch (e) {
      print('❌ Error showing background notification: $e');
      
      // Fallback: Send data to main isolate to show notification
      FlutterForegroundTask.sendDataToMain({
        'action': 'showNotification',
        'title': title,
        'message': message,
      });
    }
  }
}