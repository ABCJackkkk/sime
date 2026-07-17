import 'package:flutter/cupertino.dart';
import 'package:sime/main.dart';

enum AvatarReaction { none, heartbeat, redGlow, dimmed }

class ReactiveAvatar extends StatefulWidget {
  final double size;
  final double borderRadius;
  final String charId;
  final double affection;
  final String? recentEventType;
  final double? affectionDelta;
  final Widget child;

  const ReactiveAvatar({
    super.key,
    required this.child,
    this.size = 36,
    this.borderRadius = 10,
    this.charId = '',
    this.affection = 50,
    this.recentEventType,
    this.affectionDelta,
  });

  @override
  State<ReactiveAvatar> createState() => _ReactiveAvatarState();
}

class _ReactiveAvatarState extends State<ReactiveAvatar> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _redGlowCtrl;
  late AnimationController _dimCtrl;

  bool _didDim = false;

  AvatarReaction get _reaction {
    if (widget.affectionDelta != null && widget.affectionDelta! < -2.0 && !_didDim) {
      return AvatarReaction.dimmed;
    }
    final event = widget.recentEventType ?? '';
    if (event == 'conflict' || event == 'misunderstanding' || event == 'reversal') {
      return AvatarReaction.redGlow;
    }
    if (widget.affection >= 80 && (event == 'sweet_major' || event == 'sweet.major' || event == 'sweet_minor')) {
      return AvatarReaction.heartbeat;
    }
    return AvatarReaction.none;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _redGlowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _dimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _pulseCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _pulseCtrl.reverse();
      else if (s == AnimationStatus.dismissed) _pulseCtrl.forward();
    });

    final reaction = _reaction;
    if (reaction == AvatarReaction.heartbeat) {
      _pulseCtrl.forward();
    }
    if (reaction == AvatarReaction.redGlow) {
      _redGlowCtrl.repeat(reverse: true);
    }
    if (reaction == AvatarReaction.dimmed) {
      _dimCtrl.forward();
      _didDim = true;
    }
  }

  @override
  void didUpdateWidget(ReactiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reaction = _reaction;
    if (reaction == AvatarReaction.dimmed && !_didDim) {
      _dimCtrl.forward().then((_) => _dimCtrl.reverse());
      _didDim = true;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _redGlowCtrl.dispose();
    _dimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reaction = _reaction;

    Widget avatar = widget.child;

    if (reaction == AvatarReaction.heartbeat) {
      avatar = AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) => Transform.scale(
          scale: 1.0 + (_pulseCtrl.value * 0.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha((_pulseCtrl.value * 80).round()),
                  blurRadius: 8 + (_pulseCtrl.value * 8),
                  spreadRadius: _pulseCtrl.value * 2,
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: avatar,
      );
    }

    if (reaction == AvatarReaction.redGlow) {
      avatar = AnimatedBuilder(
        animation: _redGlowCtrl,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withAlpha(20 + (_redGlowCtrl.value * 30).round()),
                blurRadius: 6 + (_redGlowCtrl.value * 4),
              ),
            ],
          ),
          child: child,
        ),
        child: avatar,
      );
    }

    if (reaction == AvatarReaction.dimmed) {
      avatar = AnimatedBuilder(
        animation: _dimCtrl,
        builder: (context, child) => Opacity(
          opacity: 1.0 - (_dimCtrl.value * 0.4),
          child: child,
        ),
        child: avatar,
      );
    }

    return SizedBox(width: widget.size, height: widget.size, child: avatar);
  }
}
