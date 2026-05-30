import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/patient_models.dart';

class AnatomyMapWidget extends StatelessWidget {
  final List<BodyPointItem> bodyPoints;
  final BodyPointItem? selectedBodyPoint;
  final ValueChanged<BodyPointItem?> onSelect;

  const AnatomyMapWidget({
    super.key,
    required this.bodyPoints,
    required this.selectedBodyPoint,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out inactive body points or those without valid coordinates
    final activePoints = bodyPoints
        .where((bp) => bp.status && bp.imageX > 0 && bp.imageY > 0)
        .toList();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF8FF), // bg-[#ebf8ff]
          border: Border.all(color: const Color(0xFFE0F2FE)), // border-sky-100
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E2D40).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1024 / 1536,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // Human body graphic
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/human-body.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                  // Render active coordinate dots
                  ...activePoints.map((bp) {
                    final double xOffset = constraints.maxWidth * (bp.imageX / 100.0);
                    final double yOffset = constraints.maxHeight * (bp.imageY / 100.0);

                    // Positioned relative to the stack
                    return Positioned(
                      left: xOffset - 25, // offset half of the touch target size
                      top: yOffset - 25,  // offset half of the touch target size
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Center(
                          child: PulsatingMarker(
                            isSelected: selectedBodyPoint?.id == bp.id,
                            label: bp.name,
                            onTap: () {
                              if (selectedBodyPoint?.id == bp.id) {
                                onSelect(null);
                              } else {
                                onSelect(bp);
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class PulsatingMarker extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final String label;

  const PulsatingMarker({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  @override
  State<PulsatingMarker> createState() => _PulsatingMarkerState();
}

class _PulsatingMarkerState extends State<PulsatingMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Pulsating outer ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_controller.value * 1.5),
                child: Opacity(
                  opacity: (1.0 - _controller.value) * 0.7,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner solid dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: widget.isSelected ? 16 : 12,
            height: widget.isSelected ? 16 : 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: widget.isSelected ? 8 : 4,
                  spreadRadius: widget.isSelected ? 2 : 1,
                ),
              ],
            ),
          ),
          // Label tooltip shown if selected
          if (widget.isSelected)
            Positioned(
              bottom: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xE61E293B), // slate-800 90%
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.label,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
