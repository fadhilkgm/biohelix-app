import 'package:flutter/material.dart';

// BHRC branding header shown at the top of auth screens.
// Use compact=true on the OTP screen for a smaller logo without taglines.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: compact ? 16 : 36),
        _LogoBox(size: compact ? 62 : 80),
        SizedBox(height: compact ? 0 : 16),
        if (!compact) ...[
          const Text(
            'BHRC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Biohelix Health & Research Center',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'PATIENT PORTAL',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 28),
        ] else ...[
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/bhrc-logo.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
