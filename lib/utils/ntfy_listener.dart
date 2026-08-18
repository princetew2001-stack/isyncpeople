import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class NtfyListener {
  static http.Client? _client;
  static bool _listening = false;
  static StreamSubscription? _subscription;

  static Future<void> start(String empPaycode) async {
    if (_listening) {
      debugPrint('🔔 Ntfy listener already running, stopping previous connection first');
      stop(); // Stop existing connection
      await Future.delayed(const Duration(seconds: 2)); // Wait for cleanup
    }
    _listening = true;

    try {
      // Get emp_paycode from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedEmpPaycode = prefs.getString('emp_paycode');

      // Use saved emp_paycode, or fallback to parameter (username)
      final ntfyTopic = savedEmpPaycode ?? empPaycode;

      if (ntfyTopic.isEmpty) {
        debugPrint('❌ No emp_paycode or username found for ntfy listener');
        _listening = false;
        return;
      }

      debugPrint('🔔 Starting ntfy SSE listener for emp_paycode (topic): $ntfyTopic');

      // Use the new URL format
      final urlString = 'http://115.124.102.153:8081/$ntfyTopic/sse';
      final uri = Uri.parse(urlString);
      debugPrint('� Connecting to ntfy URL: $uri');

      try {
        _client?.close();
        _client = http.Client();
        final request = http.Request('GET', uri);
        request.headers['Accept'] = 'text/event-stream';
        request.headers['Cache-Control'] = 'no-cache';
        request.headers['Connection'] = 'keep-alive';
        request.headers['User-Agent'] = 'Flutter-App/1.0';
        
        debugPrint('📋 Request headers: ${request.headers}');

        debugPrint('📡 Attempting to connect to ntfy server...');
        final response = await _client!.send(request).timeout(
          const Duration(minutes: 10), // Match ARR requestTimeout
          onTimeout: () {
            debugPrint('⏰ Connection timeout for URL: $urlString (10 minutes)');
            throw TimeoutException('Connection timeout', const Duration(minutes: 10));
          },
        );
        debugPrint('✅ Connected to ntfy server! Status: ${response.statusCode}');
        debugPrint('📋 Response headers: ${response.headers}');

        // Check for rate limiting (HTTP 429)
        if (response.statusCode == 429) {
          debugPrint('❌ Rate limited! Too many active subscriptions');
          debugPrint('� Waiting 60 seconds for server cleanup before retry...');
          _listening = false;
          _client?.close();
          _client = null;
          
          // Wait longer for server to clean up existing connections
          Future.delayed(const Duration(seconds: 60), () {
            if (!_listening) {
              debugPrint('� Retrying after extended rate limit cooldown...');
              start(empPaycode);
            }
          });
          return;
        }

        // Check if we're getting HTML instead of SSE
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          debugPrint('❌ Received HTML instead of SSE! Content-Type: $contentType');
          debugPrint('💡 Server returned HTML page instead of event stream');
          _listening = false;
          _client?.close();
          _client = null;
          
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (!_listening) {
              debugPrint('🔄 Retrying ntfy connection...');
              start(empPaycode);
            }
          });
          return;
        }

        // Success! Start listening to the stream
        debugPrint('🎉 Successfully connected to ntfy SSE endpoint!');
        debugPrint('✅ Ready to receive visitor notifications');
        
        // Connection test notification removed - no notification on reconnect
        
        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) async {
          if (!_listening) return;

          debugPrint('� Received SSE line: $line');

          if (line.startsWith('data:')) {
            final jsonString = line.replaceFirst('data:', '').trim();
            if (jsonString.isEmpty) return;

            try {
              final data = json.decode(jsonString);
              debugPrint('📦 Parsed SSE data: $data');

              if (data['event'] == 'message') {
                debugPrint('📨 Received ntfy message: ${data['message']}');

                // Simple notification format
                await NotificationService.showMotivationalNotification(
                  'New Visitor',
                  data['message'] ?? 'Someone wants to meet you',
                );
              } else if (data['event'] == 'keep-alive' || data['event'] == 'keepalive') {
                // Ignore keep-alive events - don't show notification
                debugPrint('💓 Keep-alive event received - ignoring');
                return;
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing SSE message: $e');
              
              // If JSON parsing fails, treat as simple text message
              if (jsonString.isNotEmpty && 
                  !jsonString.contains('keep-alive') && 
                  !jsonString.contains('keepalive')) {
                debugPrint('📨 Treating as simple text message: $jsonString');
                await NotificationService.showMotivationalNotification(
                  'New Visitor',
                  jsonString,
                );
              }
            }
          } else if (line.isNotEmpty && 
                     !line.startsWith(':') && 
                     !line.contains('keep-alive') && 
                     !line.contains('keepalive') &&
                     !line.startsWith('event:')) {
            // Handle direct text messages (non-JSON) but ignore keep-alive and SSE events
            debugPrint('📨 Received direct message: $line');
            await NotificationService.showMotivationalNotification(
              'New Visitor',
              line,
            );
          } else if (line.startsWith('event:')) {
            // Handle SSE event lines
            debugPrint('🔄 SSE event received: $line');
            if (line.contains('keepalive') || line.contains('keep-alive')) {
              debugPrint('💓 Keep-alive event - ignoring');
            }
            // Don't show notifications for any event: lines
            return;
          }
        }, onError: (e) {
          debugPrint('❌ ntfy stream error: $e');
          _listening = false;
          _subscription?.cancel();
          _subscription = null;
          _client?.close();
          _client = null;

          // Retry after 10 seconds
          Future.delayed(const Duration(seconds: 10), () {
            if (!_listening) {
              debugPrint('🔄 Retrying ntfy connection...');
              start(empPaycode);
            }
          });
        }, onDone: () {
          debugPrint('⚠️ ntfy stream closed - attempting reconnect in 5 seconds...');
          _listening = false;
          _subscription?.cancel();
          _subscription = null;
          _client?.close();
          _client = null;
          
          // Auto-reconnect after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (!_listening) {
              debugPrint('� Reconnecting to ntfy...');
              start(empPaycode);
            }
          });
        });

        return; // Successfully connected
      } catch (e) {
        debugPrint('❌ Error connecting to ntfy: $e');
        _client?.close();
        
        // Retry after 30 seconds
        Future.delayed(const Duration(seconds: 30), () {
          if (!_listening) {
            debugPrint('🔄 Retrying ntfy connection...');
            start(empPaycode);
          }
        });
        return;
      }
    } catch (e) {
      debugPrint('❌ Error starting ntfy listener: $e');
      _listening = false;
      _client?.close();
      _client = null;

      // Retry after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (!_listening) {
          debugPrint('🔄 Retrying ntfy connection...');
          start(empPaycode);
        }
      });
    }
  }

  static void stop() {
    debugPrint('🛑 Stopping ntfy listener');
    _listening = false;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
}