import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../core/models/home_feed_models.dart';

class HomeAnnouncementTickerWidget extends StatefulWidget {
  const HomeAnnouncementTickerWidget({
    super.key,
    required this.items,
    required this.fallbackText,
    required this.onItemTap,
  });

  final List<TickerMessageItem> items;
  final String fallbackText;
  final Future<void> Function(TickerMessageItem item) onItemTap;

  @override
  State<HomeAnnouncementTickerWidget> createState() =>
      _HomeAnnouncementTickerWidgetState();
}

class _HomeAnnouncementTickerWidgetState
    extends State<HomeAnnouncementTickerWidget>
    with SingleTickerProviderStateMixin {
  static const _gap = 28.0;
  static const _itemSpacing = 14.0;
  static const _iconWidth = 12.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((item) => item.message.trim().isNotEmpty)
        .toList(growable: false);

    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFE5EEF7),
        border: Border(
          top: BorderSide(color: Color(0xFF17A6D6), width: 2),
          bottom: BorderSide(color: Color(0xFFD5E1EF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (items.isEmpty) {
              return _TickerTrack(
                items: const [],
                fallbackText: widget.fallbackText,
                onItemTap: widget.onItemTap,
              );
            }

            final cycleWidth =
                math.max(
                  _measureCycleWidth(context, items),
                  constraints.maxWidth,
                ) +
                _gap;
            final duration = Duration(
              milliseconds: math.max(10000, (cycleWidth * 42).round()),
            );
            if (_controller.duration != duration) {
              _controller.duration = duration;
              if (_controller.isAnimating) {
                _controller
                  ..reset()
                  ..repeat();
              }
            }
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final shift = _controller.value * cycleWidth;
                return Transform.translate(
                  offset: Offset(-shift, 0),
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TickerTrack(
                          items: items,
                          fallbackText: widget.fallbackText,
                          onItemTap: widget.onItemTap,
                        ),
                        const SizedBox(width: _gap),
                        _TickerTrack(
                          items: items,
                          fallbackText: widget.fallbackText,
                          onItemTap: widget.onItemTap,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  double _measureCycleWidth(
    BuildContext context,
    List<TickerMessageItem> items,
  ) {
    var total = 0.0;
    for (final item in items) {
      total += _measureTextWidth(context, item.message);
      total += (_itemSpacing * 2) + _iconWidth;
    }
    return total;
  }

  double _measureTextWidth(BuildContext context, String value) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _TickerText.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }
}

class _TickerTrack extends StatelessWidget {
  const _TickerTrack({
    required this.items,
    required this.fallbackText,
    required this.onItemTap,
  });

  final List<TickerMessageItem> items;
  final String fallbackText;
  final Future<void> Function(TickerMessageItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _TickerText(text: fallbackText);
    }

    return Row(
      children: [
        for (final item in items) ...[
          _TickerItem(item: item, onTap: () => onItemTap(item)),
          const SizedBox(width: 14),
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFF1B4D78)),
          const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _TickerItem extends StatelessWidget {
  const _TickerItem({required this.item, required this.onTap});

  final TickerMessageItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _TickerText(text: item.message),
    );
  }
}

class _TickerText extends StatelessWidget {
  const _TickerText({required this.text});

  static const style = TextStyle(
    color: Color(0xFF1B4D78),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: style,
      ),
    );
  }
}
