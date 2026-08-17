import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // Common texts
  String get dashboard => locale.languageCode == 'hi' ? 'डैशबोर्ड' : 'Dashboard';
  String get clocking => locale.languageCode == 'hi' ? 'पंचिंग' : 'Punching';
  String get attendance => locale.languageCode == 'hi' ? 'उपस्थिति' : 'Attendance';
  String get leaves => locale.languageCode == 'hi' ? 'छुट्टी' : 'Leaves';
  String get approvals => locale.languageCode == 'hi' ? 'अनुमोदन' : 'Approvals';
  String get settings => locale.languageCode == 'hi' ? 'सेटिंग्स' : 'Settings';
  String get profile => locale.languageCode == 'hi' ? 'प्रोफाइल' : 'MY PROFILE';
  
  // Attendance related
  String get present => locale.languageCode == 'hi' ? 'उपस्थित' : 'Present';
  String get absent => locale.languageCode == 'hi' ? 'अनुपस्थित' : 'Absent';
  String get holiday => locale.languageCode == 'hi' ? 'छुट्टी' : 'Holiday';
  String get checkIn => locale.languageCode == 'hi' ? 'क्लॉक इन' : 'CLOCK IN';
  String get checkOut => locale.languageCode == 'hi' ? 'क्लॉक आउट' : 'CLOCK OUT';
  
  // Settings
  String get darkMode => locale.languageCode == 'hi' ? 'डार्क मोड' : 'Dark Mode';
  String get language => locale.languageCode == 'hi' ? 'भाषा' : 'Language';
  String get notifications => locale.languageCode == 'hi' ? 'सूचनाएं' : 'Notifications';
  
  // Time related
  String get currentLocation => locale.languageCode == 'hi' ? 'वर्तमान स्थान' : 'Current Location';
  String get lastClocking => locale.languageCode == 'hi' ? 'अंतिम पंचिंग' : 'LAST PUNCHING';
  
  // Actions
  String get save => locale.languageCode == 'hi' ? 'सेव करें' : 'Save';
  String get cancel => locale.languageCode == 'hi' ? 'रद्द करें' : 'Cancel';
  String get confirm => locale.languageCode == 'hi' ? 'पुष्टि करें' : 'Confirm';
  String get ok => locale.languageCode == 'hi' ? 'ठीक है' : 'OK';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}