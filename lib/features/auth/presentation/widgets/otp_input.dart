import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 6-box OTP input that auto-advances focus across each digit.
// Calls [onCompleted] when all 6 digits are filled.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onCompleted,
    required this.onChanged,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String> onChanged;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  static const int _length = 6;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<FocusNode> _keyboardFocusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
    _keyboardFocusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentValue => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste: distribute digits across boxes
      final digits = value.replaceAll(RegExp(r'\D'), '');
      final start = digits.length >= _length ? 0 : index;
      for (int i = 0; start + i < _length && i < digits.length; i++) {
        _controllers[start + i].text = digits[i];
      }
      final nextEmpty = start + digits.length;
      if (nextEmpty < _length) {
        _focusNodes[nextEmpty].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.length == 1) {
      if (index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final current = _currentValue;
    widget.onChanged(current);
    if (current.length == _length) {
      widget.onCompleted(current);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      widget.onChanged(_currentValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        _length,
        (i) => _DigitBox(
          controller: _controllers[i],
          focusNode: _focusNodes[i],
          keyboardFocusNode: _keyboardFocusNodes[i],
          onChanged: (v) => _onDigitChanged(i, v),
          onKeyEvent: (e) => _onKeyEvent(i, e),
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.keyboardFocusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode keyboardFocusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 44,
      height: 52,
      child: KeyboardListener(
        focusNode: keyboardFocusNode,
        onKeyEvent: onKeyEvent,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            contentPadding: EdgeInsets.zero,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
