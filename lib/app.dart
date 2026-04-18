import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/storage/auth_storage.dart';

import 'core/theme/app_theme.dart';
import 'patient_portal/core/data/patient_repository.dart';
import 'patient_portal/core/providers/patient_portal_provider.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/session/providers/session_provider.dart';

class BioHelixApp extends StatefulWidget {
  const BioHelixApp({super.key});

  @override
  State<BioHelixApp> createState() => _BioHelixAppState();
}

class _BioHelixAppState extends State<BioHelixApp> {
  late final AppConfig _config;
  late final AuthStorage _authStorage;
  late final ApiClient _apiClient;
  late final PatientRepository _patientRepository;
  late final SessionProvider _sessionProvider;
  late final PatientPortalProvider _patientPortalProvider;
  final ThemeProvider _themeProvider = ThemeProvider();
  final LanguageProvider _languageProvider = LanguageProvider();

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
    _authStorage = AuthStorage();
    _apiClient = ApiClient(config: _config);
    _patientRepository = PatientRepository(apiClient: _apiClient);
    _sessionProvider = SessionProvider(
      authStorage: _authStorage,
      apiClient: _apiClient,
      patientRepository: _patientRepository,
    )..initialize();
    _patientPortalProvider = PatientPortalProvider(
      repository: _patientRepository,
      sessionProvider: _sessionProvider,
    );
    _languageProvider.initialize();
  }

  @override
  void dispose() {
    _patientPortalProvider.dispose();
    _sessionProvider.dispose();
    _themeProvider.dispose();
    _languageProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: _config),
        Provider<AuthStorage>.value(value: _authStorage),
        Provider<ApiClient>.value(value: _apiClient),
        Provider<PatientRepository>.value(value: _patientRepository),
        ChangeNotifierProvider<SessionProvider>.value(value: _sessionProvider),
        ChangeNotifierProvider<PatientPortalProvider>.value(
          value: _patientPortalProvider,
        ),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: _languageProvider,
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: _config.appName,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.mode,
          locale: languageProvider.locale,
          supportedLocales: const [Locale('en'), Locale('ml')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
