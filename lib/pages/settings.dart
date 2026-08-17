import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state variables
  // Hidden functionality - kept for backend use
  bool liveLocationTracking = true;
  bool autoCheckoutReminder = true;
  bool notificationsEnabled = true;
  String selectedTimeZone = 'Asia/Kolkata (GMT+5:30)';
  TimeOfDay workingHoursStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay workingHoursEnd = const TimeOfDay(hour: 18, minute: 0);
  
  // Visible settings
  bool darkModeEnabled = false;
  String selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    // Initialize dark mode state based on current theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final brightness = Theme.of(context).brightness;
      setState(() {
        darkModeEnabled = brightness == Brightness.dark;
      });
    });
  }

  // Kept for future use - timezone functionality
  final List<String> timeZones = [
    'Asia/Kolkata (GMT+5:30)',
    'America/New_York (GMT-5:00)',
    'Europe/London (GMT+0:00)',
    'Asia/Tokyo (GMT+9:00)',
    'Australia/Sydney (GMT+10:00)',
  ];

  final List<String> languages = [
    'English',
    'Hindi',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
              colors: [
                Color(0xFF4CAF50), // Green
                Color(0xFF2196F3), // Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Better scroll performance
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance Section
              _buildSectionHeader('Appearance'),
              _buildSettingsCard([
                _buildToggleItem(
                  'Dark Mode',
                  'Switch between light and dark theme',
                  Icons.dark_mode,
                  darkModeEnabled,
                  (value) {
                    setState(() => darkModeEnabled = value);
                    final app = AttendanceApp.of(context);
                    if (app != null) {
                      app.changeTheme(value ? ThemeMode.dark : ThemeMode.light);
                      
                      // Update system UI overlay style for dark/light mode
                      SystemChrome.setSystemUIOverlayStyle(
                        SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: value ? Brightness.light : Brightness.dark,
                          systemNavigationBarColor: value ? Colors.black : Colors.white,
                          systemNavigationBarIconBrightness: value ? Brightness.light : Brightness.dark,
                        ),
                      );
                    }
                    _showSuccessMessage(
                      value ? 'Dark mode enabled' : 'Light mode enabled'
                    );
                  },
                ),
                const Divider(height: 1),
                _buildDropdownItem(
                  'Language',
                  'Select your preferred language',
                  Icons.language,
                  selectedLanguage,
                  languages,
                  (value) {
                    setState(() => selectedLanguage = value!);
                    final app = AttendanceApp.of(context);
                    if (app != null) {
                      Locale newLocale;
                      if (value == 'Hindi') {
                        newLocale = const Locale('hi', 'IN');
                      } else {
                        newLocale = const Locale('en', 'US');
                      }
                      app.changeLanguage(newLocale);
                    }
                    _showSuccessMessage('Language changed to $value');
                  },
                ),
              ]),

              const SizedBox(height: 20),

              // About Section
              _buildSectionHeader('About'),
              _buildSettingsCard([
                _buildInfoItem(
                  'App Version',
                  '1.0.0',
                  Icons.info,
                ),
                const Divider(height: 1),
                _buildActionItem(
                  'Privacy Policy',
                  'View our privacy policy',
                  Icons.privacy_tip,
                  () => _showPrivacyPolicy(),
                ),
                const Divider(height: 1),
                _buildActionItem(
                  'Terms of Service',
                  'View terms and conditions',
                  Icons.description,
                  () => _showTermsOfService(),
                ),
              ]),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFD2691E),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleItem(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    final theme = Theme.of(context);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD2691E),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFD2691E),
      ),
    );
  }

  Widget _buildDropdownItem(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD2691E),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: options.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Kept for future use - Time picker functionality
  // ignore: unused_element
  Widget _buildTimePickerItem(
    String title,
    String subtitle,
    IconData icon,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD2691E),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildActionItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD2691E),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoItem(
    String title,
    String value,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFD2691E),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Kept for future use - Working hours dialog functionality
  // ignore: unused_element
  void _showWorkingHoursDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        TimeOfDay tempStart = workingHoursStart;
        TimeOfDay tempEnd = workingHoursEnd;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Set Working Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(tempStart.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: tempStart,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tempStart = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(tempEnd.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: tempEnd,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tempEnd = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      workingHoursStart = tempStart;
                      workingHoursEnd = tempEnd;
                    });
                    Navigator.pop(context);
                    _showSuccessMessage('Working hours updated successfully');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD2691E),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Kept for future use - Data export functionality
  // ignore: unused_element
  void _exportData(String format) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Export Data ($format)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                format == 'CSV' ? Icons.file_download : Icons.picture_as_pdf,
                size: 48,
                color: const Color(0xFFD2691E),
              ),
              const SizedBox(height: 16),
              Text(
                'Export your attendance data as $format file?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage('$format export started. Check your downloads folder.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2691E),
              ),
              child: const Text(
                'Export',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    _showInfoDialog('Privacy Policy', 'Your privacy is important to us. This app collects location data only for attendance tracking purposes and does not share your personal information with third parties.');
  }

  void _showTermsOfService() {
    _showInfoDialog('Terms of Service', 'By using this attendance app, you agree to our terms and conditions. Please use the app responsibly and ensure accurate attendance reporting.');
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(content),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2691E),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
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
}