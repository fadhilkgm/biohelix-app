import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';
import 'core/widgets/custom_button.dart';
import 'core/widgets/custom_text_field.dart';
import 'features/auth/presentation/widgets/auth_form_widgets.dart';

Future<void> main() async {
  final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
  if (kDebugMode && !isFlutterTest) {
    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(
        isInteractiveWidget: (type) =>
            type == CustomButton ||
            type == CustomTextField ||
            type == AuthTextField ||
            type == AuthDropdownField ||
            type == AuthPrimaryButton,
        extractText: (element) {
          final widget = element.widget;
          if (widget is CustomButton) return widget.text;
          if (widget is CustomTextField) return widget.label;
          if (widget is AuthTextField) return widget.label;
          if (widget is AuthDropdownField) return widget.label;
          if (widget is AuthPrimaryButton) return widget.label;
          return null;
        },
        logCollector: PrintLogCollector(),
      ),
    );
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const BioHelixApp());
}
