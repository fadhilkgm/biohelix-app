part of 'package:biohelix_app/patient_portal/shell/patient_app_shell.dart';


class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({
    required this.title,
    required this.subtitle,
    required this.onViewAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: onViewAll,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('View all'),
        ),
      ],
    );
  }
}

class _HorizontalCardRail extends StatefulWidget {
  const _HorizontalCardRail({
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
  });

  final double height;
  final int itemCount;
  final double itemExtent;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_HorizontalCardRail> createState() => _HorizontalCardRailState();
}

class _HorizontalCardRailState extends State<_HorizontalCardRail> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateBy(double delta) {
    if (!_controller.hasClients) return;

    final target = (_controller.offset + delta).clamp(
      0,
      _controller.position.maxScrollExtent,
    );

    _controller.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollStep = widget.itemExtent * 0.9;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Scroll left',
              onPressed: () => _animateBy(-scrollStep),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Scroll right',
              onPressed: () => _animateBy(scrollStep),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ),
          ],
        ),
        SizedBox(
          height: widget.height,
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            child: ListView.separated(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              scrollDirection: Axis.horizontal,
              itemCount: widget.itemCount,
              separatorBuilder: (_, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) => SizedBox(
                width: widget.itemExtent,
                child: widget.itemBuilder(context, index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

