import 'dart:async';

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

enum _CheckupView { connecting, conversation, result, history, error }

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
  });

  final AiCheckupServiceFactory? serviceFactory;
  final AiCheckupVoiceControllerFactory? voiceControllerFactory;

  @override
  State<AiCheckupTab> createState() => _AiCheckupTabState();
}

class _AiCheckupTabState extends State<AiCheckupTab> {
  late final LiveVoiceController _voice;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ConversationMessage> _messages = [];

  _CheckupView _view = _CheckupView.connecting;
  VoiceAssessmentSession? _session;
  VoiceAssessmentTurnDecision? _pendingDecision;
  AssessmentResults? _result;
  String? _error;
  bool _textFallback = false;
  bool _sendingText = false;
  bool _ending = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startAssessment());
    });
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
    });

    try {
      final session = await _service.startVoiceAssessment(
        language: _isMalayalam ? 'ml' : 'en',
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
      await _voice.start(
        locale: _isMalayalam ? 'ml-IN' : 'en-IN',
        conversationId: session.sessionToken,
        initialResponseInstructions:
            'Speak exactly the following text naturally, without adding '
            'anything: ${session.initialInstructions}',
        enableUsageTracking: false,
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
    _appendMessage(patient: true, text: transcript);
    final decision = await _service.submitVoiceTurn(
      sessionToken: session.sessionToken,
      transcript: transcript,
    );
    if (mounted) {
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
    _appendMessage(patient: false, text: response);
    try {
      await _service.recordVoiceResponse(
        sessionToken: session.sessionToken,
        transcript: transcript,
        response: response,
      );
    } catch (_) {
      // The assessment decision is already saved. A transcript persistence
      // retry must not keep the microphone open or lose the completed result.
    }
    final decision = _pendingDecision;
    if (decision?.completed == true) {
      await _showCompletedResult(decision!.result);
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
    _appendMessage(patient: true, text: text);
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
    setState(() {
      _result = result ?? _result;
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
          _result = result;
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

  void _goHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    PatientAppShell.of(context).goHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: AppChevronBackButton(onPressed: _goHome),
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
          onHome: _goHome,
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
            child: _VoiceHeader(
              patientName: _session?.patientName ?? 'Patient',
              state: state,
              textMode: _textFallback,
            ),
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
          if (_textFallback)
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
  const _VoiceHeader({
    required this.patientName,
    required this.state,
    required this.textMode,
  });

  final String patientName;
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
                  'Checkup for $patientName',
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
    required this.onHome,
  });

  final AssessmentResults? result;
  final VoidCallback onNewCheckup;
  final VoidCallback onHome;

  String _outcome(String value) => switch (value) {
    'test_package_only' => 'Test package may be suitable',
    'consultation_only' => 'Consultation may be suitable',
    'test_package_and_consultation' =>
      'Testing and consultation may be suitable',
    'emergency_escalation' => 'Emergency care recommended',
    _ => 'Advice only',
  };

  IconData _icon(String value) => switch (value) {
    'test_package_only' => Icons.science_outlined,
    'consultation_only' => Icons.medical_services_outlined,
    'test_package_and_consultation' => Icons.health_and_safety_outlined,
    'emergency_escalation' => Icons.emergency_rounded,
    _ => Icons.self_improvement_rounded,
  };

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
                _outcome(data.outcome),
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
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Phase 1 provides an assessment outcome only. No test or '
                  'consultation has been booked.',
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
