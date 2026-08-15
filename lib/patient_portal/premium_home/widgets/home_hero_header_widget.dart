import 'package:flutter/material.dart';
import 'package:biohelix_app/core/widgets/app_logo.dart';
import 'home_language_toggle_widget.dart';

class HomeHeroHeaderWidget extends StatelessWidget {
  const HomeHeroHeaderWidget({
    super.key,
    required this.greeting,
    required this.patientName,
    this.onSwitchPatient,
    this.hospitalName = 'BHRC Hospital',
  });

  final String greeting;
  final String patientName;
  final VoidCallback? onSwitchPatient;
  final String hospitalName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 150),
              child: Row(
                children: [
                  const AppLogo(size: 32, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      hospitalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              greeting,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Flexible(
                  child: Text(
                    patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
                if (onSwitchPatient != null) ...[
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Switch patient',
                    child: Tooltip(
                      message: 'Switch patient',
                      child: Material(
                        key: const ValueKey('home-switch-patient-button'),
                        color: Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onSwitchPatient,
                          customBorder: const CircleBorder(),
                          child: const SizedBox.square(
                            dimension: 36,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF06489B),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const Positioned(top: 0, right: 0, child: HomeLanguageToggleWidget()),
      ],
    );
  }
}
