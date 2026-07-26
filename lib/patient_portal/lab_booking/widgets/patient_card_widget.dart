import 'package:flutter/material.dart';
import '../models/lab_booking_models.dart';

class PatientCardWidget extends StatelessWidget {
  const PatientCardWidget({
    super.key,
    required this.patient,
    required this.selected,
    required this.onTap,
  });

  final PatientProfile patient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF06489B)
                : Colors.black.withValues(alpha: 0.05),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF06489B).withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF06489B)
                    : const Color(0xFFF4F7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                patient.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF06489B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF2D3142),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${patient.age} yrs • ${patient.gender}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF06489B),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
