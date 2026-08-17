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
  static Timer? _reconnectTimer;

  static void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  static void _scheduleReconnect(String empPaycode, Duration delay) {
    _cancelReconnectTimer();
    _reconnectTimer = Timer(delay, () {
      if (!_listening) {
        debugPrint('🔄 Triggering scheduled ntfy reconnect (delay: ${delay.inSeconds}s)...');
        start(empPaycode);
      }
    });
  }

  static Future<void> start(String empPaycode) async {
    _cancelReconnectTimer();

    if (_listening) {
      debugPrint('🔔 Ntfy listener already running, resetting connection...');
      stop();
      await Future.delayed(const Duration(milliseconds: 500));
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

      final urlString = 'http://115.124.102.153:8081/$ntfyTopic/sse';
      final uri = Uri.parse(urlString);
      debugPrint('📡 Connecting to ntfy URL: $uri');

      try {
        _client?.close();
        _client = http.Client();
        final request = http.Request('GET', uri);
        request.headers['Accept'] = 'text/event-stream';
        request.headers['Cache-Control'] = 'no-cache';
        request.headers['Connection'] = 'keep-alive';
        request.headers['User-Agent'] = 'Flutter-App/1.0';

        final response = await _client!.send(request).timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            debugPrint('⏰ Connection timeout for URL: $urlString');
            throw TimeoutException('Connection timeout', const Duration(minutes: 10));
          },
        );
        debugPrint('✅ Connected to ntfy server! Status: ${response.statusCode}');

        // Check for rate limiting (HTTP 429)
        if (response.statusCode == 429) {
          debugPrint('❌ Rate limited! Waiting 60 seconds before retrying...');
          _listening = false;
          _client?.close();
          _client = null;
          _scheduleReconnect(empPaycode, const Duration(seconds: 60));
          return;
        }

        // Check if we're getting HTML instead of SSE
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('text/html')) {
          debugPrint('❌ Received HTML instead of SSE. Retrying in 30s...');
          _listening = false;
          _client?.close();
          _client = null;
          _scheduleReconnect(empPaycode, const Duration(seconds: 30));
          return;
        }

        debugPrint('🎉 Successfully connected to ntfy SSE endpoint!');

        _subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) async {
          if (!_listening) return;

          if (line.startsWith('data:')) {
            final jsonString = line.replaceFirst('data:', '').trim();
            if (jsonString.isEmpty) return;

            try {
              final data = json.decode(jsonString);
              if (data['event'] == 'message') {
                debugPrint('📨 Received ntfy message: ${data['message']}');
                await NotificationService.showMotivationalNotification(
                  'New Visitor',
                  data['message'] ?? 'Someone wants to meet you',
                );
              } else if (data['event'] == 'keep-alive' || data['event'] == 'keepalive') {
                return;
              }
            } catch (e) {
              if (jsonString.isNotEmpty &&
                  !jsonString.contains('keep-alive') &&
                  !jsonString.contains('keepalive')) {
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
            await NotificationService.showMotivationalNotification(
              'New Visitor',
              line,
            );
          }
        }, onError: (e) {
          debugPrint('❌ ntfy stream error: $e');
          _listening = false;
          _subscription?.cancel();
          _subscription = null;
          _client?.close();
          _client = null;
          _scheduleReconnect(empPaycode, const Duration(seconds: 10));
        }, onDone: () {
          debugPrint('⚠️ ntfy stream closed - scheduling reconnect in 5s...');
          _listening = false;
          _subscription?.cancel();
          _subscription = null;
          _client?.close();
          _client = null;
          _scheduleReconnect(empPaycode, const Duration(seconds: 5));
        });

        return;
      } catch (e) {
        debugPrint('❌ Error connecting to ntfy: $e');
        _client?.close();
        _listening = false;
        _scheduleReconnect(empPaycode, const Duration(seconds: 30));
        return;
      }
    } catch (e) {
      debugPrint('❌ Error starting ntfy listener: $e');
      _listening = false;
      _client?.close();
      _client = null;
      _scheduleReconnect(empPaycode, const Duration(seconds: 10));
    }
  }

  static void stop() {
    debugPrint('🛑 Stopping ntfy listener');
    _listening = false;
    _cancelReconnectTimer();
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }
}