import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef InitialReferralLinkReader = Future<Uri?> Function();
typedef InstallReferrerReader = Future<String?> Function();
typedef ReferralPreferencesReader = Future<SharedPreferences> Function();

class ReferralLinkProvider extends ChangeNotifier {
  ReferralLinkProvider({
    required InitialReferralLinkReader initialLinkReader,
    required Stream<Uri> linkStream,
    required InstallReferrerReader installReferrerReader,
    required ReferralPreferencesReader preferencesReader,
    this.allowedHttpsHost = 'demo.bhrchospital.com',
  }) : _initialLinkReader = initialLinkReader,
       _linkStream = linkStream,
       _installReferrerReader = installReferrerReader,
       _preferencesReader = preferencesReader;

  factory ReferralLinkProvider.production({
    String allowedHttpsHost = 'demo.bhrchospital.com',
  }) {
    final appLinks = AppLinks();
    return ReferralLinkProvider(
      initialLinkReader: appLinks.getInitialLink,
      linkStream: appLinks.uriLinkStream,
      installReferrerReader: _readNativeInstallReferrer,
      preferencesReader: SharedPreferences.getInstance,
      allowedHttpsHost: allowedHttpsHost,
    );
  }

  static const _pendingCodeKey = 'pending_referral_code';
  static const _pendingSourceKey = 'pending_referral_source';
  static const _installReferrerChannel = MethodChannel(
    'com.biohelix.app/install_referrer',
  );

  final InitialReferralLinkReader _initialLinkReader;
  final Stream<Uri> _linkStream;
  final InstallReferrerReader _installReferrerReader;
  final ReferralPreferencesReader _preferencesReader;
  final String allowedHttpsHost;

  StreamSubscription<Uri>? _linkSubscription;
  SharedPreferences? _preferences;
  String? _pendingCode;
  String? _pendingSource;
  bool _initialized = false;

  String? get pendingCode => _pendingCode;
  String? get pendingSource => _pendingSource;
  bool get hasPendingReferral => (_pendingCode ?? '').isNotEmpty;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    _preferences = await _preferencesReader();
    _pendingCode = _normalizeCode(_preferences?.getString(_pendingCodeKey));
    _pendingSource = _preferences?.getString(_pendingSourceKey);

    _linkSubscription = _linkStream.listen(
      (uri) {
        debugPrint('Received referral app link: $uri');
        unawaited(captureUri(uri, source: 'app_link'));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Referral link stream error: $error');
      },
    );

    try {
      final installReferrer = await _installReferrerReader();
      if (!hasPendingReferral && installReferrer != null) {
        final installCode = referralCodeFromInstallReferrer(installReferrer);
        if (installCode != null) {
          await _store(installCode, source: 'play_install_referrer');
        }
      }
    } catch (error) {
      debugPrint('Play Install Referrer read failed: $error');
    }

    try {
      final initialUri = await _initialLinkReader();
      if (initialUri != null) {
        await captureUri(initialUri, source: 'initial_app_link');
      }
    } catch (error) {
      debugPrint('Initial referral link read failed: $error');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<bool> captureUri(Uri uri, {required String source}) async {
    final code = referralCodeFromUri(uri);
    if (code == null) return false;
    await _store(code, source: source);
    return true;
  }

  String? referralCodeFromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'https') {
      if (uri.host.toLowerCase() != allowedHttpsHost.toLowerCase()) return null;
      if (uri.pathSegments.length < 2 ||
          uri.pathSegments.first.toLowerCase() != 'r') {
        return null;
      }
      return _normalizeCode(uri.pathSegments[1]);
    }

    if (scheme == 'bhrc' && uri.host.toLowerCase() == 'referral') {
      if (uri.pathSegments.isEmpty) return null;
      return _normalizeCode(uri.pathSegments.first);
    }

    return null;
  }

  String? referralCodeFromInstallReferrer(String rawReferrer) {
    var decoded = rawReferrer.trim();
    if (decoded.isEmpty) return null;

    try {
      decoded = Uri.decodeComponent(decoded);
    } on FormatException {
      // The Play API normally returns a decoded query string already.
    }

    final asUri = Uri.tryParse(decoded);
    if (asUri != null && asUri.hasScheme) {
      final directCode = referralCodeFromUri(asUri);
      if (directCode != null) return directCode;
      return _normalizeCode(asUri.queryParameters['referral_code']);
    }

    try {
      return _normalizeCode(Uri.splitQueryString(decoded)['referral_code']);
    } on FormatException {
      return null;
    }
  }

  Future<void> consumeIfMatches(String? submittedCode) async {
    final normalizedSubmitted = _normalizeCode(submittedCode);
    if (normalizedSubmitted == null || normalizedSubmitted != _pendingCode) {
      return;
    }

    await consume();
  }

  Future<void> consume() async {
    _pendingCode = null;
    _pendingSource = null;
    await _preferences?.remove(_pendingCodeKey);
    await _preferences?.remove(_pendingSourceKey);
    notifyListeners();
  }

  Future<void> _store(String code, {required String source}) async {
    if (_pendingCode == code && _pendingSource == source) return;
    _pendingCode = code;
    _pendingSource = source;
    debugPrint('Stored referral code from $source');
    await _preferences?.setString(_pendingCodeKey, code);
    await _preferences?.setString(_pendingSourceKey, source);
    notifyListeners();
  }

  static String? _normalizeCode(String? rawCode) {
    final code = (rawCode ?? '').trim().toUpperCase();
    if (!RegExp(r'^BHRC[A-Z0-9]{6,12}$').hasMatch(code)) return null;
    return code;
  }

  static Future<String?> _readNativeInstallReferrer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _installReferrerChannel.invokeMethod<String>(
        'getInstallReferrer',
      );
    } on PlatformException catch (error) {
      debugPrint('Play Install Referrer unavailable: ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }
}
