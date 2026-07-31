import 'package:flutter/cupertino.dart';

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  final Duration duration;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.95,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.scaleAmount).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _pressed) {
        _pressed = false;
        _ctrl.reverse();
        widget.onTap?.call();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _pressed = true;
        _ctrl.forward();
      },
      onTapUp: (_) {
        _pressed = false;
        if (_ctrl.isAnimating) {
          _ctrl.reverse();
        }
      },
      onTapCancel: () {
        _pressed = false;
        _ctrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: widget.child,
      ),
    );
  }
}
