import 'package:flutter/widgets.dart';

typedef BattleAnimationWidgetBuilder = Widget Function(
  BuildContext context,
  double progress,
  Widget? child,
);

/// A one-shot presentation animation whose timeline stops during battle pause.
/// Unlike TickerMode, resuming does not skip the time spent in the settings.
class BattlePausableAnimation extends StatefulWidget {
  const BattlePausableAnimation({
    super.key,
    required this.duration,
    required this.paused,
    required this.builder,
    this.child,
  });

  final Duration duration;
  final bool paused;
  final BattleAnimationWidgetBuilder builder;
  final Widget? child;

  @override
  State<BattlePausableAnimation> createState() =>
      _BattlePausableAnimationState();
}

class _BattlePausableAnimationState extends State<BattlePausableAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (!widget.paused) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BattlePausableAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.paused) {
      _controller.stop(canceled: false);
    } else if (!_controller.isCompleted &&
        (oldWidget.paused || oldWidget.duration != widget.duration)) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
    );
  }
}
