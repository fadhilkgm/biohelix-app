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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppLogo(size: 32, fit: BoxFit.contain),
                  const SizedBox(width: 8),
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ],
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
                        child: InkWell(
                          key: const ValueKey('home-switch-patient-button'),
                          onTap: onSwitchPatient,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.switch_account_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Switch',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
        ),
        const HomeLanguageToggleWidget(),
      ],
    );
  }
}
