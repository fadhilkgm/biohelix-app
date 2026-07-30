import 'dart:async';

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
import 'patient_portal/fitness/providers/fitness_provider.dart';

class _ClampedScrollBehavior extends MaterialScrollBehavior {
  const _ClampedScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

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
  late final LanguageProvider _languageProvider;
  late final FitnessProvider _fitnessProvider;
  late final Future<void> _languageInitialization;
  final ThemeProvider _themeProvider = ThemeProvider();
  bool _languageSyncedForSession = false;

  @override
  void initState() {
    super.initState();
    _config = AppConfig.fromEnvironment();
    _authStorage = AuthStorage();
    _apiClient = ApiClient(config: _config);
    _apiClient.setOnUnauthorized(() {
      // SessionProvider owns recovery while bootstrapping or switching saved
      // patient profiles. Only a stable signed-in session should be globally
      // signed out by an unrelated 401 response.
      if (_sessionProvider.state == SessionState.signedIn &&
          _sessionProvider.isAuthenticated) {
        unawaited(_sessionProvider.signOut());
      }
    });
    _patientRepository = PatientRepository(apiClient: _apiClient);
    _sessionProvider = SessionProvider(
      authStorage: _authStorage,
      apiClient: _apiClient,
      patientRepository: _patientRepository,
    )..initialize();
    _languageProvider = LanguageProvider(apiClient: _apiClient);
    _languageInitialization = _languageProvider.initialize();
    _sessionProvider.addListener(_handleSessionChanged);
    _patientPortalProvider = PatientPortalProvider(
      repository: _patientRepository,
      sessionProvider: _sessionProvider,
    );
    _fitnessProvider = FitnessProvider(
      repository: _patientRepository,
      sessionProvider: _sessionProvider,
      onRewardsChanged: _patientPortalProvider.refreshMyClub,
    )..initialize();
  }

  void _handleSessionChanged() {
    if (!_sessionProvider.isAuthenticated) {
      _languageSyncedForSession = false;
      return;
    }
    if (_languageSyncedForSession) return;
    _languageSyncedForSession = true;
    unawaited(_syncLanguageAfterLogin());
  }

  Future<void> _syncLanguageAfterLogin() async {
    await _languageInitialization;
    await _languageProvider.syncToServer();
  }

  @override
  void dispose() {
    _sessionProvider.removeListener(_handleSessionChanged);
    _patientPortalProvider.dispose();
    _fitnessProvider.dispose();
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
        ChangeNotifierProvider<FitnessProvider>.value(value: _fitnessProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        ChangeNotifierProvider<LanguageProvider>.value(
          value: _languageProvider,
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, languageProvider, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _ClampedScrollBehavior(),
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
          builder: (context, child) => DefaultTextStyle.merge(
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontFamilyFallback: ['AnekMalayalam'],
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
