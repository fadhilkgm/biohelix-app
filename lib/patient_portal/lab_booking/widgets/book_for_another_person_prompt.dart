import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookForAnotherPersonPrompt extends StatelessWidget {
  const BookForAnotherPersonPrompt({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? const Color(0xFF5A88F1) : const Color(0xFFE5E9F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.group_add_outlined,
                color: Color(0xFF5A88F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Book for another person?',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF192233),
                ),
              ),
            ),
            IgnorePointer(
              child: Switch.adaptive(
                value: value,
                activeThumbColor: const Color(0xFF5A88F1),
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
