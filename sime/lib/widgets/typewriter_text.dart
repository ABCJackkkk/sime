import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:sime/main.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed;
  final bool enabled;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style = const TextStyle(),
    this.speed = const Duration(milliseconds: 40),
    this.enabled = true,
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _visibleChars = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled && widget.text.isNotEmpty) {
      _startTyping();
    } else {
      _visibleChars = widget.text.length;
      _done = true;
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (_) {
      if (_visibleChars < widget.text.length) {
        setState(() {
          _visibleChars++;
        });
      } else {
        _timer.cancel();
        _done = true;
        widget.onComplete?.call();
      }
    });
  }

  void skip() {
    if (_done) return;
    _timer.cancel();
    setState(() {
      _visibleChars = widget.text.length;
      _done = true;
    });
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer.cancel();
      _visibleChars = 0;
      _done = false;
      if (widget.enabled) _startTyping();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done || !widget.enabled) {
      return Text(widget.text, style: widget.style);
    }

    final displayText = widget.text.substring(0, _visibleChars);
    final lastCharIndex = _visibleChars - 1;

    return GestureDetector(
      onTap: skip,
      child: Text.rich(
        TextSpan(
          children: List.generate(displayText.length, (i) {
            final charOpacity = i >= lastCharIndex - 2 ? 1.0 : (0.6 + (i / displayText.length) * 0.4).clamp(0.6, 1.0);
            return TextSpan(
              text: displayText[i],
              style: widget.style.copyWith(
                color: (widget.style.color ?? AppColors.textPrimaryDark).withAlpha((charOpacity * 255).round()),
              ),
            );
          }),
        ),
        style: widget.style.copyWith(color: (widget.style.color ?? AppColors.textPrimaryDark).withAlpha(0)),
      ),
    );
  }
}
