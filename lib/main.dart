import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/login.dart';
import 'pages/permissions.dart';
import 'utils/app_localizations.dart';
import 'utils/notification_service.dart';
import 'utils/ntfy_background_service.dart';
import 'utils/app_update_service.dart';
import 'utils/auth_service.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.initialize();
  
  // Initialize background service for ntfy
  await NtfyBackgroundService.initialize();
  
  // Check and reset daily data if needed on app startup
  await _checkDailyReset();

  // Setup 401 unauthorized handler
  AuthService.onUnauthorized = () {
    debugPrint('🚨 401 Handler: Redirecting to login screen');
    // Navigate to login screen and clear all previous routes
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  };

  // Set Android status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const AttendanceApp());
}

Future<void> _checkDailyReset() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastResetDateStr = prefs.getString('last_reset_date');
    final currentDate = DateTime.now();
    final currentDateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
    
    if (lastResetDateStr != currentDateStr) {
      // It's a new day, reset all daily clocking data
      await prefs.remove('is_currently_clocked_in');
      await prefs.remove('current_check_in_time');
      await prefs.remove('current_check_in_location');
      await prefs.remove('current_check_in_coordinates');
      await prefs.remove('current_work_duration');
      await prefs.remove('today_check_out_time');
      await prefs.remove('today_check_out_location');
      await prefs.remove('today_check_out_coordinates');
      await prefs.setString('last_reset_date', currentDateStr);
    }
  } catch (e) {
    debugPrint('Error in daily reset check: $e');
  }
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  static AttendanceAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<AttendanceAppState>();

  @override
  State<AttendanceApp> createState() => AttendanceAppState();
}

class AttendanceAppState extends State<AttendanceApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('en', 'US');

  @override
  void initState() {
    super.initState();
    // Run update check after first frame so navigatorKey.currentContext is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        AppUpdateService.checkForUpdate(context: ctx);
      }
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    
    // Update system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: themeMode == ThemeMode.dark ? Colors.black : Colors.white,
        systemNavigationBarIconBrightness: themeMode == ThemeMode.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  void changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  Future<bool> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('permissions_requested') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add global navigator key
      title: 'ClockWise',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('en', 'US'), // English
        Locale('hi', 'IN'), // Hindi
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),
      home: FutureBuilder<bool>(
        future: _checkFirstTime(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFD2691E),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          return snapshot.data == true ? const PermissionsPage() : const LoginPage();
        },
      ),
    );
  }
}
