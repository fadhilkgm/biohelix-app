import 'package:flutter/material.dart';
import 'package:biohelix_app/core/widgets/app_logo.dart';
import 'home_language_toggle_widget.dart';

class HomeHeroHeaderWidget extends StatelessWidget {
  const HomeHeroHeaderWidget({
    super.key,
    required this.greeting,
    required this.patientName,
    this.hospitalName = 'BHRC Hospital',
  });

  final String greeting;
  final String patientName;
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
                children: [
                  ClipOval(
                    child: AppLogo(
                      size: 22,
                      fit: BoxFit.cover,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hospitalName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
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
              Text(
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
            ],
          ),
        ),
        const HomeLanguageToggleWidget(),
      ],
    );
  }
}
