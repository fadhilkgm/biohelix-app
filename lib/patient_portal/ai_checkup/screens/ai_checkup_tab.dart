import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_chevron_back_button.dart';
import '../../../features/session/providers/session_provider.dart';
import '../../assistant/voice/inworld_signaling_api.dart';
import '../../assistant/voice/live_voice_controller.dart';
import '../../assistant/voice/live_voice_state.dart';
import '../../shell/patient_app_shell.dart';
import '../services/ai_checkup_service.dart';

typedef AiCheckupServiceFactory =
    AiCheckupService Function(BuildContext context);

typedef AiCheckupVoiceControllerFactory =
    LiveVoiceController Function({
      required InworldSignalingApi signalingApi,
      required RealtimeTurnCompleted onTurnCompleted,
      required RealtimeTurnContext onTurnContext,
    });

typedef AiCheckupPackageOpener = void Function(String? packageTarget);
typedef AiCheckupDoctorOpener =
    void Function(AssessmentRecommendedDoctor doctor, String? sourceSession);
typedef AiCheckupTestsOpener =
    void Function(List<AssessmentRecommendedTest> tests, String? sourceSession);
typedef AiCheckupEmergencyOpener = VoidCallback;
typedef AiCheckupSupportOpener = VoidCallback;

AiCheckupService _defaultServiceFactory(BuildContext context) {
  return AiCheckupService(
    apiBaseUrl: context.read<AppConfig>().apiBaseUrl,
    authToken: context.read<SessionProvider>().authToken ?? '',
  );
}

LiveVoiceController _defaultVoiceControllerFactory({
  required InworldSignalingApi signalingApi,
  required RealtimeTurnCompleted onTurnCompleted,
  required RealtimeTurnContext onTurnContext,
}) {
  return LiveVoiceController(
    signalingApi: signalingApi,
    onTurnCompleted: onTurnCompleted,
    onTurnContext: onTurnContext,
  );
}

enum _CheckupView { consent, connecting, conversation, result, history, error }

class _ConversationMessage {
  const _ConversationMessage({required this.patient, required this.text});

  final bool patient;
  final String text;
}

/// Phase-one AI Checkup: a repeatable, voice-first clinical intake that
/// produces a safe disposition but never creates a lab or doctor booking.
class AiCheckupTab extends StatefulWidget {
  const AiCheckupTab({
    super.key,
    this.serviceFactory,
    this.voiceControllerFactory,
    this.onOpenPackage,
    this.onOpenDoctor,
    this.onOpenTests,
    this.onOpenEmergency,
    this.onOpenSupport,
    this.consentInitiallyGranted = false,
    this.resultRevealDelay = const Duration(milliseconds: 500),
  });

  final AiCheckupServiceFactory? serviceFactory;
  final AiCheckupVoiceControllerFactory? voiceControllerFactory;
  final AiCheckupPackageOpener? onOpenPackage;
  final AiCheckupDoctorOpener? onOpenDoctor;
  final AiCheckupTestsOpener? onOpenTests;
  final AiCheckupEmergencyOpener? onOpenEmergency;
  final AiCheckupSupportOpener? onOpenSupport;
  final bool consentInitiallyGranted;
  final Duration resultRevealDelay;

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  late final LiveVoiceController _voice;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ConversationMessage> _messages = [];

  _CheckupView _view = _CheckupView.consent;
  VoiceAssessmentSession? _session;
  VoiceAssessmentTurnDecision? _pendingDecision;
  AssessmentResults? _result;
  String? _error;
  bool _textFallback = false;
  bool _sendingText = false;
  bool _ending = false;
  Future<void> _responsePersistence = Future<void>.value();
  bool _allowPop = false;
  bool _consentGranted = false;
  Timer? _sessionTimer;

  AiCheckupService get _service =>
      (widget.serviceFactory ?? _defaultServiceFactory)(context);

  bool get _isMalayalam =>
      context.read<LanguageProvider>().language == AppLanguage.ml;

  @override
  void initState() {
    super.initState();
    final signalingApi = InworldSignalingApi(context.read<ApiClient>());
    _voice = (widget.voiceControllerFactory ?? _defaultVoiceControllerFactory)(
      signalingApi: signalingApi,
      onTurnCompleted: _onVoiceTurnCompleted,
      onTurnContext: _onVoiceTurnContext,
    );
    _voice.addListener(_onVoiceStateChanged);
    _consentGranted = widget.consentInitiallyGranted;
    if (_consentGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startAssessment());
      });
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _voice.removeListener(_onVoiceStateChanged);
    _voice.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startAssessment() async {
    if (!_consentGranted) {
      if (mounted) setState(() => _view = _CheckupView.consent);
      return;
    }
    _sessionTimer?.cancel();
    if (_voice.state.isActive) {
      await _voice.stop(reason: 'new_assessment');
    }
    if (!mounted) return;
    setState(() {
      _view = _CheckupView.connecting;
      _session = null;
      _pendingDecision = null;
      _result = null;
      _messages.clear();
      _error = null;
      _textFallback = false;
      _ending = false;
      _responsePersistence = Future<void>.value();
      _allowPop = false;
    });

    try {
      final session = await _service.startVoiceAssessment(
        language: _isMalayalam ? 'ml' : 'en',
        consent: true,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _view = _CheckupView.conversation;
        _messages.add(
          _ConversationMessage(
            patient: false,
            text: session.initialInstructions,
          ),
        );
      });
      _sessionTimer = Timer(Duration(seconds: session.maxSeconds), () {
        if (mounted) unawaited(_finishForTimeLimit());
      });
      // Desktop WebRTC can terminate the host process before the controller
      // reports an error. Keep desktop builds usable (and testable) by using
      // the existing text path; mobile builds remain voice-first.
      if (widget.voiceControllerFactory == null &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        setState(() => _textFallback = true);
        return;
      }
      await _voice.start(
        locale: _isMalayalam ? 'ml-IN' : 'en-IN',
        conversationId: session.sessionToken,
        initialResponseInstructions:
            'Speak exactly the following text naturally, without adding '
            'anything: ${session.initialInstructions}',
        enableUsageTracking: false,
        sessionInstructions: session.realtimeInstructions,
      );
      if (!mounted) return;
      if (_voice.state.phase == LiveVoicePhase.error) {
        setState(() {
          _textFallback = true;
          _error = _voice.state.errorMessage;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _view = _CheckupView.error;
        _error = _friendlyError(error);
      });
    }
  }

  Future<String> _onVoiceTurnContext(String transcript) async {
    final session = _session;
    if (session == null) {
      throw StateError('The voice assessment session is unavailable.');
    }
    final decision = await _service.recordRealtimeTurn(
      sessionToken: session.sessionToken,
      transcript: transcript,
    );
    if (mounted) {
      _appendMessage(patient: true, text: decision.acceptedTranscript);
      setState(() {
        _pendingDecision = decision;
        _result = decision.result ?? _result;
      });
    }
    return decision.responseInstructions;
  }

  Future<void> _onVoiceTurnCompleted(String transcript, String response) async {
    final session = _session;
    if (session == null || !mounted) return;
    final decision = _pendingDecision;
    final safeResponse = decision?.completed == true
        ? decision?.spokenResponse ?? response
        : response;
    if (safeResponse.isNotEmpty) {
      _appendMessage(patient: false, text: safeResponse);
    }
    final persistence = _queueVoiceResponse(
      sessionToken: session.sessionToken,
      transcript: transcript,
      response: safeResponse,
    );
    if (_isCompletionSignal(safeResponse, session.completionPhrase)) {
      await persistence;
      await _finalizeRealtimeCheckup();
      return;
    }
    if (decision?.completed == true) {
      await persistence;
      if (widget.resultRevealDelay > Duration.zero) {
        await Future<void>.delayed(widget.resultRevealDelay);
      }
      if (!mounted) return;
      await _showCompletedResult(decision!.result);
    }
  }

  bool _isCompletionSignal(String response, String completionPhrase) {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final phrase = normalize(completionPhrase);
    return phrase.isNotEmpty && normalize(response).contains(phrase);
  }

  Future<void> _finalizeRealtimeCheckup() async {
    final session = _session;
    if (_ending || session == null) return;
    _ending = true;
    _sessionTimer?.cancel();
    await _voice.stop(reason: 'assessment_finalizing');

    try {
      final decision = await _service.finalizeVoiceAssessment(
        sessionToken: session.sessionToken,
      );
      if (widget.resultRevealDelay > Duration.zero) {
        await Future<void>.delayed(widget.resultRevealDelay);
      }
      if (!mounted) return;
      final result = decision.result;
      setState(() {
        _pendingDecision = decision;
        _result = result?.withSourceSession(session.sessionToken);
        _view = _CheckupView.result;
        _ending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _view = _CheckupView.error;
        _error = _friendlyError(error);
        _ending = false;
      });
    }
  }

  Future<void> _queueVoiceResponse({
    required String sessionToken,
    required String transcript,
    required String response,
  }) {
    _responsePersistence = _responsePersistence.then(
      (_) => _recordVoiceResponseSafely(
        sessionToken: sessionToken,
        transcript: transcript,
        response: response,
      ),
    );

    return _responsePersistence;
  }

  Future<void> _recordVoiceResponseSafely({
    required String sessionToken,
    required String transcript,
    required String response,
  }) async {
    try {
      await _service.recordVoiceResponse(
        sessionToken: sessionToken,
        transcript: transcript,
        response: response,
      );
    } catch (_) {
      // The assessment decision is already saved. Transcript persistence must
      // not delay the closing speech or the result transition.
    }
  }

  void _onVoiceStateChanged() {
    if (!mounted) return;
    final state = _voice.state;
    if (state.phase == LiveVoicePhase.error) {
      setState(() {
        _textFallback = true;
        _error = state.errorMessage;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _sendingText) return;
    _textController.clear();
    setState(() {
      _sendingText = true;
      _error = null;
    });
    try {
      final decision = await _service.submitVoiceTurn(
        sessionToken: session.sessionToken,
        transcript: text,
      );
      if (!mounted) return;
      _appendMessage(patient: true, text: decision.acceptedTranscript);
      _appendMessage(patient: false, text: decision.spokenResponse);
      await _service.recordVoiceResponse(
        sessionToken: session.sessionToken,
        transcript: text,
        response: decision.spokenResponse,
      );
      if (decision.completed) {
        await _showCompletedResult(decision.result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _sendingText = false);
    }
  }

  Future<void> _showCompletedResult(AssessmentResults? result) async {
    if (_ending) return;
    _ending = true;
    _sessionTimer?.cancel();
    await _voice.stop(reason: 'assessment_completed');
    if (!mounted) return;
    final sourceToken = _session?.sessionToken;
    setState(() {
      final resolved = result ?? _result;
      _result = resolved != null && sourceToken != null
          ? resolved.withSourceSession(sourceToken)
          : resolved;
      _view = _CheckupView.result;
      _ending = false;
    });
  }

  Future<void> _finishForTimeLimit() async {
    if (_ending || _view != _CheckupView.conversation) return;
    _ending = true;
    await _voice.stop(reason: 'time_limit');
    final session = _session;
    if (session != null) {
      try {
        await _service.cancelVoiceAssessment(session.sessionToken);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _view = _CheckupView.error;
      _error = _isMalayalam
          ? 'അഞ്ച് മിനിറ്റ് സമയപരിധി കഴിഞ്ഞു. പുതിയ പരിശോധന ആരംഭിക്കാം.'
          : 'The five-minute limit was reached. You can start a new checkup.';
      _ending = false;
    });
  }

  Future<void> _endAssessment() async {
    if (_ending) return;
    _ending = true;
    _sessionTimer?.cancel();
    await _voice.stop(reason: 'patient_ended');
    final session = _session;
    if (session != null) {
      try {
        await _service.cancelVoiceAssessment(session.sessionToken);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _view = _CheckupView.error;
      _error = _isMalayalam
          ? 'പരിശോധന അവസാനിപ്പിച്ചു.'
          : 'The checkup was ended.';
      _ending = false;
    });
  }

  void _appendMessage({required bool patient, required String text}) {
    if (!mounted || text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ConversationMessage(patient: patient, text: text.trim()));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openHistory() async {
    if (_voice.state.isActive) {
      await _endAssessment();
    }
    if (mounted) setState(() => _view = _CheckupView.history);
  }

  Future<void> _openHistoryResult(AssessmentHistoryItem item) async {
    setState(() {
      _view = _CheckupView.connecting;
      _error = null;
    });
    try {
      final result = await _service.getResults(item.sessionToken);
      if (mounted) {
        setState(() {
          _result = result.withSourceSession(item.sessionToken);
          _view = _CheckupView.result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _view = _CheckupView.history;
          _error = _friendlyError(error);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _leaveCheckup() async {
    if (_ending) return;
    if (_view == _CheckupView.connecting ||
        _view == _CheckupView.conversation) {
      await _endAssessment();
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    PatientAppShell.of(context).goHome();
  }

  void _openPackage([String? packageTarget]) {
    final openPackage = widget.onOpenPackage;
    if (openPackage != null) {
      openPackage(packageTarget);
      return;
    }

    PatientAppShell.of(context).openPackages(packageTarget);
  }

  void _openDoctor(AssessmentRecommendedDoctor doctor) {
    widget.onOpenDoctor?.call(doctor, _result?.sourceSessionToken);
  }

  void _openTests(List<AssessmentRecommendedTest> tests) {
    widget.onOpenTests?.call(tests, _result?.sourceSessionToken);
  }

  void _grantConsent() {
    setState(() => _consentGranted = true);
    unawaited(_startAssessment());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leaveCheckup());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6F8FC),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: AppChevronBackButton(
              onPressed: () => unawaited(_leaveCheckup()),
            ),
          ),
          title: const Text(
            'AI Health Checkup',
            style: TextStyle(
              color: Color(0xFF192233),
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'History',
              onPressed: _view == _CheckupView.connecting ? null : _openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: switch (_view) {
          _CheckupView.consent => _ConsentView(
            onAccept: _grantConsent,
            onDecline: () => unawaited(_leaveCheckup()),
          ),
          _CheckupView.connecting => const _StatusMessage(
            icon: Icons.graphic_eq_rounded,
            title: 'Preparing private voice checkup',
            subtitle: 'Connecting securely and loading your health context…',
            loading: true,
          ),
          _CheckupView.conversation => _buildConversation(),
          _CheckupView.result => _ResultView(
            result: _result,
            onNewCheckup: _startAssessment,
            onPackages: _openPackage,
            onPackage: (package) => _openPackage(package.packageName),
            onDoctor: _openDoctor,
            onTests: _openTests,
            onEmergency: widget.onOpenEmergency ?? () {},
            onSupport: widget.onOpenSupport ?? widget.onOpenEmergency ?? () {},
            onHome: () => unawaited(_leaveCheckup()),
          ),
          _CheckupView.history => _HistoryView(
            load: _service.listHistory,
            onOpen: _openHistoryResult,
            onStart: _startAssessment,
            error: _error,
          ),
          _CheckupView.error => _StatusMessage(
            icon: Icons.mic_off_rounded,
            title: _error ?? 'The voice checkup could not continue.',
            subtitle: 'No test or consultation was booked.',
            actionLabel: 'Start again',
            onAction: _startAssessment,
          ),
        },
      ),
    );
  }

  Widget _buildConversation() {
    final state = _voice.state;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: _VoiceHeader(state: state, textMode: _textFallback),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _MessageBubble(message: _messages[index]),
            ),
          ),
          if ((_error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _InlineError(message: _error!),
            ),
          if (_ending)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  LinearProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Preparing your checkup result…'),
                ],
              ),
            )
          else if (_textFallback)
            _TextFallbackComposer(
              controller: _textController,
              sending: _sendingText,
              onSend: _sendText,
            )
          else
            _VoiceControls(
              state: state,
              onInterrupt: state.isSpeaking ? _voice.interrupt : null,
              onUseText: () => setState(() => _textFallback = true),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _ending ? null : _endAssessment,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End checkup'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC03D3D),
                  side: const BorderSide(color: Color(0xFFE8BABA)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceHeader extends StatelessWidget {
  const _VoiceHeader({required this.state, required this.textMode});

  final LiveVoiceState state;
  final bool textMode;

  String get _status {
    if (textMode) return 'Text fallback';
    return switch (state.phase) {
      LiveVoicePhase.connecting => 'Connecting…',
      LiveVoicePhase.speaking => 'AI is speaking',
      LiveVoicePhase.thinking || LiveVoicePhase.transcribing => 'Thinking…',
      LiveVoicePhase.reconnecting => 'Reconnecting…',
      _ => 'Listening',
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = state.isListening || state.isSpeaking;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06489B), Color(0xFF1769C2)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 58 + (active ? state.soundLevel * 12 : 0),
            height: 58 + (active ? state.soundLevel * 12 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.17),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
            child: Icon(
              textMode ? Icons.chat_bubble_outline : Icons.graphic_eq_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private AI health checkup',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _status,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Max 5 min',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.patient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: message.patient ? const Color(0xFF06489B) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: message.patient
              ? null
              : Border.all(color: const Color(0xFFE0E6EF)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.patient ? Colors.white : const Color(0xFF273348),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _VoiceControls extends StatelessWidget {
  const _VoiceControls({
    required this.state,
    required this.onInterrupt,
    required this.onUseText,
  });

  final LiveVoiceState state;
  final Future<void> Function()? onInterrupt;
  final VoidCallback onUseText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onUseText,
            icon: const Icon(Icons.keyboard_rounded),
            label: const Text('Use text'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onInterrupt,
            icon: Icon(
              state.isSpeaking
                  ? Icons.record_voice_over_rounded
                  : Icons.mic_rounded,
            ),
            label: Text(state.isSpeaking ? 'Interrupt' : 'Listening'),
          ),
        ],
      ),
    );
  }
}

class _TextFallbackComposer extends StatelessWidget {
  const _TextFallbackComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: TextField(
        controller: controller,
        enabled: !sending,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => onSend(),
        decoration: InputDecoration(
          hintText: 'Type your answer…',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDCE3ED)),
          ),
          suffixIcon: IconButton(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1CCCC)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF9A3333), fontSize: 12),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onNewCheckup,
    required this.onPackages,
    required this.onPackage,
    required this.onDoctor,
    required this.onTests,
    required this.onEmergency,
    required this.onSupport,
    required this.onHome,
  });

  final AssessmentResults? result;
  final VoidCallback onNewCheckup;
  final VoidCallback onPackages;
  final ValueChanged<AssessmentRecommendedPackage> onPackage;
  final ValueChanged<AssessmentRecommendedDoctor> onDoctor;
  final ValueChanged<List<AssessmentRecommendedTest>> onTests;
  final VoidCallback onEmergency;
  final VoidCallback onSupport;
  final VoidCallback onHome;

  String _outcome(AssessmentResults data) {
    if (data.outcome == 'emergency_escalation') {
      return 'Emergency care recommended';
    }
    if (_needsHumanSupport(data)) {
      return 'Hospital support recommended';
    }
    if (data.customPackage != null && data.recommendedPackages.isEmpty) {
      return 'Custom panel ready for review';
    }
    if (data.recommendedTests.isNotEmpty && data.recommendedPackages.isEmpty) {
      return data.recommendedDoctors.isNotEmpty
          ? 'Testing and consultation may be suitable'
          : 'Lab tests may be suitable';
    }

    return switch (data.outcome) {
      'test_package_only' => 'Test package may be suitable',
      'consultation_only' => 'Consultation may be suitable',
      'test_package_and_consultation' =>
        'Testing and consultation may be suitable',
      _ => 'Advice only',
    };
  }

  IconData _icon(String value) => switch (value) {
    'test_package_only' => Icons.science_outlined,
    'consultation_only' => Icons.medical_services_outlined,
    'test_package_and_consultation' => Icons.health_and_safety_outlined,
    'emergency_escalation' => Icons.emergency_rounded,
    _ => Icons.self_improvement_rounded,
  };

  bool _needsHumanSupport(AssessmentResults data) {
    if (data.urgency == 'emergency' || data.intent == 'advice') {
      return false;
    }

    return switch (data.intent) {
      'doctor_booking' => data.recommendedDoctors.isEmpty,
      'test_booking' =>
        data.recommendedTests.isEmpty && data.recommendedPackages.isEmpty,
      'custom_package' => data.customPackage == null,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = result;
    if (data == null) {
      return _StatusMessage(
        icon: Icons.info_outline,
        title: 'Checkup completed',
        subtitle: 'No booking was created.',
        actionLabel: 'Start new checkup',
        onAction: onNewCheckup,
      );
    }
    final needsHumanSupport = _needsHumanSupport(data);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDDE5EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _icon(data.outcome),
                size: 38,
                color: data.outcome == 'emergency_escalation'
                    ? const Color(0xFFC83A3A)
                    : const Color(0xFF06489B),
              ),
              const SizedBox(height: 14),
              Text(
                _outcome(data),
                style: const TextStyle(
                  color: Color(0xFF192233),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.summary,
                style: const TextStyle(color: Color(0xFF56657A), height: 1.5),
              ),
              if (data.insights.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Key points',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF273348),
                  ),
                ),
                const SizedBox(height: 8),
                ...data.insights.map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: Color(0xFF1769C2),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(insight)),
                      ],
                    ),
                  ),
                ),
              ],
              if (data.urgency != 'emergency' &&
                  data.recommendedDoctors.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Recommended doctors',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF273348),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.recommendedDoctors.map(
                  (doctor) => _AiCheckupDoctorCard(
                    doctor: doctor,
                    onTap: () => onDoctor(doctor),
                  ),
                ),
              ],
              if (data.urgency != 'emergency' &&
                  data.recommendedTests.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Recommended lab tests',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF273348),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.recommendedTests.map(
                  (test) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.science_outlined,
                      color: Color(0xFF1769C2),
                    ),
                    title: Text(
                      test.testName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: (test.reason ?? '').trim().isEmpty
                        ? null
                        : Text(test.reason!),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => onTests(data.recommendedTests),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Review selected tests'),
                ),
              ],
              if (data.urgency != 'emergency' &&
                  data.customPackage != null) ...[
                const SizedBox(height: 20),
                _AiCheckupCustomPanelCard(
                  package: data.customPackage!,
                  onReview: () => onTests(data.customPackage!.tests),
                ),
              ],
              if (data.urgency != 'emergency' &&
                  data.recommendedPackages.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Recommended health packages',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF273348),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...data.recommendedPackages.map(
                  (package) => _AiCheckupPackageCard(
                    package: package,
                    onTap: () => onPackage(package),
                  ),
                ),
              ],
              if (needsHumanSupport) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF0D39D)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF9A6212),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No matching active option is available right now. Contact BHRC reception for a safe human review.',
                          style: TextStyle(
                            color: Color(0xFF714A13),
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  data.urgency == 'emergency'
                      ? 'Emergency guidance does not create a booking. Seek urgent care now.'
                      : 'No test or consultation has been booked. Recommendations require your confirmation.',
                  style: TextStyle(
                    color: Color(0xFF53647A),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (data.urgency == 'emergency') ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC83A3A),
            ),
            onPressed: onEmergency,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Open emergency contacts'),
          ),
          const SizedBox(height: 10),
        ] else if (data.recommendedPackages.isNotEmpty) ...[
          FilledButton.icon(
            onPressed: onPackages,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('View health packages'),
          ),
          const SizedBox(height: 10),
        ] else if (needsHumanSupport) ...[
          FilledButton.icon(
            onPressed: onSupport,
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contact hospital support'),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          onPressed: onNewCheckup,
          child: const Text('Start new voice checkup'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onHome, child: const Text('Back to home')),
      ],
    );
  }
}

class _AiCheckupCustomPanelCard extends StatelessWidget {
  const _AiCheckupCustomPanelCard({
    required this.package,
    required this.onReview,
  });

  final AssessmentCustomPackage package;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(package.price ?? '');
    final validUntil = package.validUntil?.toLocal();
    final validity = validUntil == null
        ? null
        : '${validUntil.day}/${validUntil.month}/${validUntil.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBE5D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: Color(0xFF14845D)),
              SizedBox(width: 8),
              Text(
                'Draft custom panel',
                style: TextStyle(
                  color: Color(0xFF14845D),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            package.name,
            style: const TextStyle(
              color: Color(0xFF192233),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if ((package.reason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(package.reason!),
          ],
          const SizedBox(height: 10),
          Text(
            '${package.tests.length} tests${price == null ? '' : ' • ₹${price.toStringAsFixed(0)}'}${validity == null ? '' : ' • Valid until $validity'}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: package.tests.isEmpty ? null : onReview,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Review and edit panel'),
          ),
        ],
      ),
    );
  }
}

class _AiCheckupDoctorCard extends StatelessWidget {
  const _AiCheckupDoctorCard({required this.doctor, required this.onTap});

  final AssessmentRecommendedDoctor doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final specialization = (doctor.specialization ?? '').trim();
    final reason = (doctor.reason ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF7FAFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD9E6F7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE7F0FC),
            child: Icon(
              Icons.medical_services_outlined,
              color: Color(0xFF06489B),
            ),
          ),
          title: Text(
            doctor.name,
            style: const TextStyle(
              color: Color(0xFF192233),
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            [
              specialization,
              reason,
            ].where((value) => value.isNotEmpty).join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _AiCheckupPackageCard extends StatelessWidget {
  const _AiCheckupPackageCard({required this.package, required this.onTap});

  final AssessmentRecommendedPackage package;
  final VoidCallback onTap;

  String _price(String value) {
    final amount = double.tryParse(value);
    if (amount == null) return value;
    return '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final effectivePrice = (package.discountedPrice ?? '').trim().isNotEmpty
        ? package.discountedPrice!
        : package.price;
    final imageUrl = (package.imageUrl ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E6F7)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 92,
                    height: 92,
                    color: Colors.white,
                    child: imageUrl.isEmpty
                        ? const Icon(
                            Icons.health_and_safety_outlined,
                            color: Color(0xFF1769C2),
                            size: 34,
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.health_and_safety_outlined,
                              color: Color(0xFF1769C2),
                              size: 34,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.packageName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF192233),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      if (package.testsCount > 0) ...[
                        const SizedBox(height: 5),
                        Text(
                          '${package.testsCount} tests included',
                          style: const TextStyle(
                            color: Color(0xFF61728A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if ((effectivePrice ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          _price(effectivePrice!),
                          style: const TextStyle(
                            color: Color(0xFF06489B),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      const Text(
                        'View package →',
                        style: TextStyle(
                          color: Color(0xFF1769C2),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryView extends StatefulWidget {
  const _HistoryView({
    required this.load,
    required this.onOpen,
    required this.onStart,
    required this.error,
  });

  final Future<List<AssessmentHistoryItem>> Function() load;
  final ValueChanged<AssessmentHistoryItem> onOpen;
  final VoidCallback onStart;
  final String? error;

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  late Future<List<AssessmentHistoryItem>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AssessmentHistoryItem>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StatusMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load checkup history',
            subtitle: snapshot.error.toString(),
            actionLabel: 'Retry',
            onAction: () => setState(() => _history = widget.load()),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return _StatusMessage(
            icon: Icons.history_toggle_off_rounded,
            title: 'No voice checkups yet',
            subtitle: 'Completed checkups will appear here.',
            actionLabel: 'Start voice checkup',
            onAction: widget.onStart,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFDDE5EF)),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F2FF),
                child: Icon(Icons.graphic_eq_rounded, color: Color(0xFF06489B)),
              ),
              title: Text(
                item.summary.isEmpty ? 'Health checkup' : item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(item.outcome.replaceAll('_', ' ')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => widget.onOpen(item),
            );
          },
        );
      },
    );
  }
}

class _ConsentView extends StatelessWidget {
  const _ConsentView({required this.onAccept, required this.onDecline});

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
      children: [
        const Icon(
          Icons.health_and_safety_outlined,
          size: 54,
          color: Color(0xFF06489B),
        ),
        const SizedBox(height: 20),
        const Text(
          'Before your private AI Checkup',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF192233),
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'With your permission, BHRC will use the conversation to prepare a health summary and recommendations. This is not a diagnosis or emergency service.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF56657A), height: 1.5),
        ),
        const SizedBox(height: 22),
        const _ConsentPoint(
          icon: Icons.mic_none_rounded,
          text:
              'Voice is processed for this checkup; raw audio is not retained by the app.',
        ),
        const _ConsentPoint(
          icon: Icons.lock_outline_rounded,
          text:
              'Redacted conversation turns are retained for up to 30 days, then removed automatically.',
        ),
        const _ConsentPoint(
          icon: Icons.task_alt_rounded,
          text:
              'No doctor, test, or package is booked without your separate confirmation.',
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: onAccept,
          child: const Text('I agree — start checkup'),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: onDecline, child: const Text('Not now')),
      ],
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  const _ConsentPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1769C2), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF06489B)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF192233),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF617086), height: 1.45),
            ),
            if (loading) ...[
              const SizedBox(height: 22),
              const CircularProgressIndicator(),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
