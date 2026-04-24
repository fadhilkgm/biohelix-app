import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCompleting = false;

  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;
    setState(() {
      _isCompleting = true;
    });
    await widget.onCompleted();
    if (!mounted) return;
    setState(() {
      _isCompleting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Light Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF0F4FF),
                    Color(0xFFFFFFFF),
                  ],
                ),
              ),
            ),
          ),
          
          // Doctor Image with Dissolve Effect
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.55, // Reduced space
            child: SafeArea(
              bottom: false,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.transparent],
                    stops: [0.75, 1.0], // Dissolves at the bottom
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/doctor-vector.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Content Area (Bottom Section)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Left aligned
                children: [
                  const Text(
                    'Your Smart Health Partner',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF192233),
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect instantly with trusted doctors, book visits online, and manage your health anytime.',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF192233).withOpacity(0.7),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _SwipeToStartSlider(
                    onCompleted: _completeOnboarding,
                    isCompleting: _isCompleting,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeToStartSlider extends StatefulWidget {
  final VoidCallback onCompleted;
  final bool isCompleting;

  const _SwipeToStartSlider({
    required this.onCompleted,
    required this.isCompleting,
  });

  @override
  State<_SwipeToStartSlider> createState() => _SwipeToStartSliderState();
}

class _SwipeToStartSliderState extends State<_SwipeToStartSlider> {
  double _dragValue = 0.0;
  final double _handleSize = 64.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDrag = totalWidth - _handleSize - 12; // 6px padding on each side

        return Container(
          width: double.infinity,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF537DE8),
            borderRadius: BorderRadius.circular(38),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF537DE8).withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Swipe to Start Text
              Opacity(
                opacity: (1.0 - (_dragValue / maxDrag)).clamp(0.1, 1.0),
                child: const Text(
                  'Swipe to Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              
              // Animated Indicator Arrows
              Positioned(
                left: 24,
                child: Opacity(
                  opacity: (1.0 - (_dragValue / (maxDrag * 0.2))).clamp(0.0, 0.4),
                  child: Row(
                    children: const [
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                      Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),

              // draggable handle
              AnimatedPositioned(
                duration: Duration(milliseconds: _dragValue == 0 ? 300 : 0),
                curve: Curves.easeOut,
                left: _dragValue + 6,
                top: 6,
                bottom: 6,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (widget.isCompleting) return;
                    setState(() {
                      _dragValue += details.delta.dx;
                      _dragValue = _dragValue.clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (widget.isCompleting) return;
                    if (_dragValue >= maxDrag * 0.75) {
                      setState(() => _dragValue = maxDrag);
                      widget.onCompleted();
                    } else {
                      setState(() => _dragValue = 0.0);
                    }
                  },
                  child: Container(
                    width: _handleSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: widget.isCompleting
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(Color(0xFF537DE8)),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: Color(0xFF537DE8),
                            size: 32,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

