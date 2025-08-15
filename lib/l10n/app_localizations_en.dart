// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Progresso';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTemplates => 'Templates';

  @override
  String get navLog => 'Log';

  @override
  String get navChat => 'Chat';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatReindexTooltip => 'Rebuild index';

  @override
  String get chatInputHint => 'Ask about your data…';

  @override
  String get chatSend => 'Send';
}
