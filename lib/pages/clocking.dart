import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../utils/app_localizations.dart';
import '../utils/location_service.dart';
import '../utils/notification_service.dart';
import '../utils/auth_service.dart';

class ClockingPage extends StatefulWidget {
  const ClockingPage({super.key});

  @override
  State<ClockingPage> createState() => _ClockingPageState();
}

class _ClockingPageState extends State<ClockingPage> with TickerProviderStateMixin {

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Location ───────────────────────────────────────────────────────────────
  String currentLocation = 'Fetching location...';
  bool isLocationLoading = true;

  // ── Punch status from API ─────────────────────────────────────────────────
  // null = not yet loaded, true/false = loaded
  bool? checkInPunched;
  bool? checkOutPunched;
  DateTime? checkInTime;
  DateTime? checkOutTime;
  String? checkInLocation;
  String? checkOutLocation;
  bool isLoadingStatus = true; // spinner while fetching punch status

  // ── Active session timer (shown when punched in, not yet punched out) ──────
  Timer? _workTimer;
  Duration workDuration = Duration.zero;

  // ── Cooldown after punch-in (2 min before punch-out is enabled) ───────────
  Timer? _cooldownTimer;
  int _cooldownSecondsLeft = 0;
  bool canClockOut = false;

  // ── Midnight reset ────────────────────────────────────────────────────────
  Timer? _midnightTimer;

  // ── Processing guard (prevent double-tap) ────────────────────────────────
  bool _isProcessing = false;

  // ── Error box after loading timeout ──────────────────────────────────────
  bool _showErrorBox = false;   // shown 5 s after a failed fetch
  Timer? _errorBoxTimer;

  // ── API config ────────────────────────────────────────────────────────────
  static const String _punchingCreateUrl =
      'https://delton.intellisync.in:11004/payroll/punching/create/';
  static const String _punchStatusBaseUrl =
      'https://delton.intellisync.in:11004/access-armor/punch_in_out_check/';

  final AuthService _authService = AuthService();
  String? _userId; // username_id for the status API

  // ── Cooldown format ───────────────────────────────────────────────────────
  String get _cooldownText {
    final m = _cooldownSecondsLeft ~/ 60;
    final s = _cooldownSecondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _getCurrentLocation();
    _loadUserId().then((_) => _fetchPunchStatus());
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _cooldownTimer?.cancel();
    _midnightTimer?.cancel();
    _errorBoxTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Animations ────────────────────────────────────────────────────────────
  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────
  void _getCurrentLocation() async {
    if (mounted) setState(() => isLocationLoading = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      if (mounted) setState(() { currentLocation = loc; isLocationLoading = false; });
    } catch (_) {
      if (mounted) setState(() { currentLocation = 'Unable to get location'; isLocationLoading = false; });
    }
  }

  // ── User ID ───────────────────────────────────────────────────────────────
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    // API needs emp_paycode (e.g. S1010631), not numeric user_id
    _userId = prefs.getString('emp_paycode')
        ?? prefs.getString('username')
        ?? prefs.getString('user_email');
    debugPrint('👤 userId for punch status: $_userId');
  }

  /// Fetch punch status from API
  Future<void> _fetchPunchStatus() async {
    if (_userId == null) {
      if (mounted) setState(() => isLoadingStatus = false);
      return;
    }
    if (mounted) {
      setState(() {
        isLoadingStatus = true;
        _showErrorBox   = false;  // reset error box on each fresh fetch
      });
    }
    // Start 5-second timer — if still loading after 5s, show error box
    _errorBoxTimer?.cancel();
    _errorBoxTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && isLoadingStatus && checkInPunched == null) {
        setState(() => _showErrorBox = true);
      }
    });

    try {
      final endpoint = '$_punchStatusBaseUrl?username_id=$_userId';
      debugPrint('🔍 Fetching punch status: $endpoint');

      // Use authenticatedRequest so session cookie is included
      final response = await _authService.authenticatedRequest(
        endpoint: endpoint,
        method: 'GET',
      );

      debugPrint('📊 Punch status (${response.statusCode}), body start: ${response.body.substring(0, response.body.length.clamp(0, 80))}');

      // Guard: only reject if body is HTML (not JSON)
      final body = response.body.trim();
      if (body.startsWith('<') || body.startsWith('<!')) {
        debugPrint('⚠️ Punch status API returned HTML — session may have expired');
        // Invalid response — keep loading screen, do not show main UI
        if (mounted) setState(() { isLoadingStatus = true; });
        return;
      }

      // 404 = user not found on server, treat as no punches today
      if (response.statusCode == 404) {
        debugPrint('ℹ️ Punch status 404 — no punch record for user today');
        _errorBoxTimer?.cancel();
        if (mounted) {
          setState(() {
            checkInPunched  = false;
            checkOutPunched = false;
            isLoadingStatus = false;
          });
        }
        return;
      }

      if (response.statusCode != 200) {
        debugPrint('⚠️ Unexpected status ${response.statusCode}');
        // Invalid response — keep loading screen, do not show main UI
        if (mounted) setState(() { isLoadingStatus = true; });
        return;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      final checkIn  = data['check_in']  as Map<String, dynamic>?;
      final checkOut = data['check_out'] as Map<String, dynamic>?;

      final inPunched  = checkIn?['punched']  == true;
      final outPunched = checkOut?['punched'] == true;

      DateTime? inTime, outTime;
      String?   inLoc, outLoc;

      if (inPunched && checkIn?['time'] != null) {
        inTime = _parseDateTime(checkIn!['time'].toString());
        inLoc  = checkIn['location']?.toString();
      }
      if (outPunched && checkOut?['time'] != null) {
        outTime = _parseDateTime(checkOut!['time'].toString());
        outLoc  = checkOut['location']?.toString();
      }

      debugPrint('📋 API says — inPunched: $inPunched, outPunched: $outPunched');

      // Safety: never downgrade checkInPunched from true→false mid-session.
      // This prevents a stale/wrong API response from flipping punch type.
      final resolvedInPunched  = (checkInPunched == true) ? true : inPunched;
      final resolvedOutPunched = outPunched;

      if (mounted) {
        _errorBoxTimer?.cancel();
        setState(() {
          checkInPunched   = resolvedInPunched;
          checkOutPunched  = resolvedOutPunched;
          checkInTime      = inTime  ?? checkInTime;
          checkOutTime     = outTime ?? checkOutTime;
          checkInLocation  = inLoc   ?? checkInLocation;
          checkOutLocation = outLoc  ?? checkOutLocation;
          isLoadingStatus  = false;
        });

        // If punched in but not out — start/resume work timer
        if (resolvedInPunched && !resolvedOutPunched && checkInTime != null) {
          _resumeWorkTimer(checkInTime!);
        } else {
          _workTimer?.cancel();
          if (checkInTime != null && checkOutTime != null) {
            setState(() => workDuration = checkOutTime!.difference(checkInTime!));
          }
          _pulseController.stop();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching punch status: $e');
      if (mounted) {
        // Keep showing loading screen on error — do not expose broken UI
        setState(() {
          isLoadingStatus = true;
        });
      }
    }
  }

  /// Resume work timer from the stored check-in time
  void _resumeWorkTimer(DateTime inTime) {
    _workTimer?.cancel();
    // Set initial duration
    setState(() {
      workDuration = DateTime.now().difference(inTime);
      canClockOut  = true; // API confirmed punched-in, allow clock-out immediately
    });
    _pulseController.repeat(reverse: true);

    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => workDuration = DateTime.now().difference(inTime));
      }
    });
  }

  // ── Perform punch (in or out) ─────────────────────────────────────────────
  Future<void> _handlePunch() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Ensure location is valid
      String location = currentLocation;
      if (location.contains('Fetching') || location.contains('Unable')) {
        try {
          location = await LocationService.getCurrentLocation();
          if (mounted) setState(() => currentLocation = location);
        } catch (_) {
          location = 'Location not available';
        }
      }

      // isPunchIn = true only if NOT yet punched in
      // If already punched in (even if checkOut state is unclear), send 'out'
      final isPunchIn = checkInPunched != true;
      final apiType   = isPunchIn ? 'in' : 'out';
      debugPrint('🧭 Punch decision — checkInPunched: $checkInPunched, checkOutPunched: $checkOutPunched → apiType: $apiType');

      final prefs = await SharedPreferences.getInstance();
      final userIdentifier = prefs.getString('user_id') ?? prefs.getString('user_email');

      if (userIdentifier == null) {
        _showError('User not found. Please login again.');
        return;
      }

      final now           = DateTime.now();
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final requestId     = '${userIdentifier}_${apiType}_${now.millisecondsSinceEpoch}';

      debugPrint('🚀 Punching $apiType — user: $userIdentifier, time: $formattedTime');

      final response = await _authService.authenticatedRequest(
        endpoint: _punchingCreateUrl,
        method: 'POST',
        body: {
          'username': userIdentifier,
          'type': apiType,
          'location': location,
          'time': formattedTime,
          'request_id': requestId,
        },
      );

      debugPrint('📊 Punch response (${response.statusCode}): ${response.body}');

      bool success = false;
      String? confirmedType; // "in" or "out" as confirmed by server response
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body.containsKey('success')) {
            success = body['success'] == true;
          } else if (body.containsKey('status')) {
            final s = body['status'];
            success = s == true || s == 'success' || s == 'ok';
          } else {
            success = true; // assume success for 2xx
          }
          // Read confirmed type from server response data
          final data = body['data'] as Map<String, dynamic>?;
          confirmedType = data?['type']?.toString(); // "in" or "out"
          debugPrint('✅ Server confirmed punch type: $confirmedType');
        } catch (_) {
          success = true;
        }
      }

      if (success) {
        // Use server-confirmed type — fallback to local isPunchIn if not available
        final actuallyPunchedIn = confirmedType == 'in' || (confirmedType == null && isPunchIn);

        // Show success popup based on what server actually recorded
        if (mounted) {
          _showSuccessPopup(
            actuallyPunchedIn ? 'CLOCK IN' : 'CLOCK OUT',
            DateFormat('HH:mm:ss').format(now),
            location,
          );
        }

        // Fire notifications
        try {
          if (actuallyPunchedIn) {
            await NotificationService.showClockInNotification();
          } else {
            await NotificationService.showClockOutNotification();
          }
        } catch (_) {}

        // Update UI based on server-confirmed type
        if (mounted) {
          setState(() {
            if (actuallyPunchedIn) {
              checkInPunched  = true;
              checkInTime     = now;
              checkInLocation = location;
              canClockOut     = false;
              workDuration    = Duration.zero;
            } else {
              checkInPunched   = true; // must still be true if punching out
              checkOutPunched  = true;
              checkOutTime     = now;
              checkOutLocation = location;
              _workTimer?.cancel();
              _cooldownTimer?.cancel();
              _pulseController.stop();
              _pulseController.reset();
              canClockOut = false;
              _cooldownSecondsLeft = 0;
            }
          });

          if (actuallyPunchedIn) {
            _startCooldown();
          }
        }

        // Re-fetch from server to get authoritative state
        await Future.delayed(const Duration(seconds: 1));
        await _fetchPunchStatus();

      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        final msg  = body['message'] ?? body['error'] ?? 'Punch failed (${response.statusCode})';
        _showError(msg.toString());
      }
    } on TimeoutException {
      _showError('Connection timeout. Please check your network.');
    } catch (e) {
      _showError('Network error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Cooldown timer (2 min after punch-in) ─────────────────────────────────
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSecondsLeft = 120);

    _pulseController.repeat(reverse: true);

    // Start work timer from now
    final inTime = checkInTime ?? DateTime.now();
    _workTimer?.cancel();
    _workTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => workDuration = DateTime.now().difference(inTime));
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _cooldownSecondsLeft--;
        if (_cooldownSecondsLeft <= 0) {
          _cooldownSecondsLeft = 0;
          canClockOut = true;
          timer.cancel();
          debugPrint('🔓 Clock-out enabled after cooldown');
        }
      });
    });
  }

  // ── Midnight reset ────────────────────────────────────────────────────────
  void _scheduleMidnightReset() {
    final now           = DateTime.now();
    final nextMidnight  = DateTime(now.year, now.month, now.day + 1);
    final timeUntil     = nextMidnight.difference(now);

    debugPrint('⏰ Midnight reset in ${timeUntil.inMinutes} min');
    _midnightTimer = Timer(timeUntil, () {
      debugPrint('🕛 Midnight — resetting state and re-fetching');
      if (mounted) {
        setState(() {
          checkInPunched   = false;
          checkOutPunched  = false;
          checkInTime      = null;
          checkOutTime     = null;
          checkInLocation  = null;
          checkOutLocation = null;
          workDuration     = Duration.zero;
          canClockOut      = false;
          _cooldownSecondsLeft = 0;
        });
        _workTimer?.cancel();
        _cooldownTimer?.cancel();
        _pulseController.stop();
        _pulseController.reset();
        _fetchPunchStatus();
        _scheduleMidnightReset(); // schedule for next day
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  DateTime _parseDateTime(String s) {
    try {
      final dt = DateTime.parse(s);
      return dt.isUtc ? dt.toLocal() : dt;
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Derived state helpers ─────────────────────────────────────────────────
  /// Is today's session fully complete? (both punched)
  bool get _isDayComplete => checkInPunched == true && checkOutPunched == true;

  /// Should the action button be disabled?
  bool get _buttonDisabled {
    if (_isProcessing || isLoadingStatus) return true;
    if (_isDayComplete) return true;
    // Clocked in but in cooldown — disable
    if (checkInPunched == true && checkOutPunched != true && _cooldownSecondsLeft > 0) return true;
    // Clocked in, cooldown done but canClockOut not set — disable
    if (checkInPunched == true && checkOutPunched != true && !canClockOut) return true;
    return false;
  }

  String get _buttonText {
    if (_isDayComplete)        return 'DAY COMPLETE';
    if (_isProcessing)         return ''; // shows spinner
    if (checkInPunched == true) {
      if (_cooldownSecondsLeft > 0) return 'WAIT $_cooldownText';
      return 'PUNCH OUT';
    }
    return 'PUNCH IN';
  }

  IconData get _buttonIcon {
    if (_isDayComplete)         return Icons.check_circle;
    if (checkInPunched == true) return Icons.logout;
    return Icons.login;
  }

  List<Color> get _buttonGradient {
    if (_buttonDisabled)        return [Colors.grey[300]!, Colors.grey[400]!];
    if (checkInPunched == true) return [Colors.red[400]!, Colors.red[600]!];
    return [const Color(0xFFD2691E), const Color(0xFF8B4513)];
  }

  Color get _buttonTextColor {
    if (_buttonDisabled) return Colors.grey[600]!;
    return Colors.white;
  }

  String _getStatusText() {
    if (isLoadingStatus)  return 'Loading...';
    if (_isDayComplete)   return 'Day Complete – Clocked Out';
    if (checkInPunched == true) {
      if (_cooldownSecondsLeft > 0) return 'Clocked In – Wait $_cooldownText';
      return 'Clocked In – Ready to Clock Out';
    }
    return 'Ready to Clock In';
  }

  Color _getStatusColor() {
    if (_isDayComplete)         return Colors.grey[600]!;
    if (checkInPunched == true) return Colors.green;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
  }

  // ── Success popup ─────────────────────────────────────────────────────────
  void _showSuccessPopup(String action, String timeStr, String location) {
    final isIn   = action == 'CLOCK IN';
    final color  = isIn ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    final bgClr  = isIn ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD);
    final icon   = isIn ? Icons.login_rounded : Icons.logout_rounded;
    final title  = isIn ? 'Punched In Successfully' : 'Punched Out Successfully';
    final sub    = isIn ? 'Have a great day at work!' : 'Great work today! See you tomorrow.';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isIn
                ? Theme.of(context).cardColor
                : const Color(0xFFF0F8FF), // Alice blue tint for punch out
            borderRadius: BorderRadius.circular(20),
            border: isIn
                ? null
                : Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: bgClr, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: bgClr, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time, size: 16, color: color),
                const SizedBox(width: 6),
                Text(timeStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Flexible(child: Text(location, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final theme      = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.clocking ?? 'Attendance Clocking',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: isLoadingStatus
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoadingStatus ? null : _fetchPunchStatus,
            tooltip: 'Refresh',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const CircleAvatar(
              backgroundColor: Colors.black54,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: isLoadingStatus && checkInPunched == null
          ? Center(
              child: _showErrorBox
                  // ── Error box (shown after 5 s of failed loading) ──────────
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/error.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Failed to load',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Could not fetch attendance status.\nPlease check your connection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _fetchPunchStatus,
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                'Retry',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD2691E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  // ── Loading spinner ────────────────────────────────────────
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD2691E)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Fetching attendance status...',
                          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ── Work duration / status card ──────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFD2691E).withValues(alpha: 0.1),
                            const Color(0xFFD2691E).withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD2691E).withValues(alpha: 0.2)),
                      ),
                      child: Column(children: [
                        if (checkInPunched == true && workDuration > Duration.zero) ...[
                          Text(
                            _formatDuration(workDuration),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFD2691E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isDayComplete ? 'Total Worked Today' : 'Work Duration',
                            style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w500),
                          ),
                          if (_cooldownSecondsLeft > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Clock out available in $_cooldownText',
                              style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ] else ...[
                          Icon(Icons.punch_clock_outlined, size: 36, color: const Color(0xFFD2691E).withValues(alpha: 0.7)),
                          const SizedBox(height: 8),
                          const Text('Not Punched In', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFD2691E))),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the button below to start your day',
                            style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
                          ),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 30),

                    // ── Pulse circle icon ────────────────────────────────────
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, __) => Transform.scale(
                        scale: (checkInPunched == true && !_isDayComplete) ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cardColor,
                            border: Border.all(
                              color: (checkInPunched == true && !_isDayComplete) ? Colors.green : const Color(0xFFD2691E),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: ((checkInPunched == true && !_isDayComplete) ? Colors.green : const Color(0xFFD2691E)).withValues(alpha: 0.3),
                                blurRadius: 20, spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            (checkInPunched == true && !_isDayComplete) ? Icons.check_circle : Icons.access_time,
                            size: 50,
                            color: (checkInPunched == true && !_isDayComplete) ? Colors.green : const Color(0xFFD2691E),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Status text ──────────────────────────────────────────
                    Text(
                      _getStatusText(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _getStatusColor()),
                    ),

                    if (checkInPunched == true && checkInTime != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Since ${timeFormat.format(checkInTime!)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // ── Action button ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(colors: _buttonGradient),
                        boxShadow: [
                          BoxShadow(
                            color: _buttonGradient.last.withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _buttonDisabled ? null : _handlePunch,
                          child: Center(
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_buttonIcon, color: _buttonTextColor, size: 24),
                                      const SizedBox(width: 12),
                                      Text(
                                        _buttonText,
                                        style: TextStyle(color: _buttonTextColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── Current location card ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFD2691E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.location_on, color: Color(0xFFD2691E), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)?.currentLocation ?? 'Current Location',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          const Spacer(),
                          if (isLocationLoading)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD2691E))))
                          else
                            IconButton(onPressed: _getCurrentLocation, icon: const Icon(Icons.refresh, color: Color(0xFFD2691E), size: 20)),
                        ]),
                        const SizedBox(height: 12),
                        Text(currentLocation, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color, height: 1.4)),
                        if (!isLocationLoading && !currentLocation.contains('Unable') && !currentLocation.contains('denied')) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.gps_fixed, size: 12, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Text('GPS Active', style: TextStyle(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 20),

                    // ── Today's activity card ─────────────────────────────────
                    if (checkInPunched == true || checkOutPunched == true)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Today's Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                          const SizedBox(height: 16),
                          if (checkInPunched == true && checkInTime != null)
                            _buildActivityItem('Punch In', timeFormat.format(checkInTime!), checkInLocation ?? currentLocation, Icons.login, Colors.green),
                          if (checkOutPunched == true && checkOutTime != null) ...[
                            const SizedBox(height: 12),
                            _buildActivityItem('Punch Out', timeFormat.format(checkOutTime!), checkOutLocation ?? currentLocation, Icons.logout, Colors.red),
                          ],
                        ]),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Activity item widget ──────────────────────────────────────────────────
  Widget _buildActivityItem(String title, String time, String location, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
          ]),
          const SizedBox(height: 4),
          Text(location, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}
