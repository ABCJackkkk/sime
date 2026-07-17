import 'package:flutter/cupertino.dart';
import 'package:sime/main.dart';

class SkeletonCard extends StatefulWidget {
  final double height;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 80,
    this.borderRadius = 16,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final a = 5 + (_ctrl.value * 8).round();
        return Container(
          height: widget.height,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: AppColors.border, width: 0.5),
            color: const Color(0x08FFFFFF),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 10, decoration: BoxDecoration(color: Color.fromARGB(a, 255, 255, 255), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Color.fromARGB(a + 2, 255, 255, 255), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Color.fromARGB(a, 255, 255, 255), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Container(width: 80, height: 10, decoration: BoxDecoration(color: Color.fromARGB(a - 2, 255, 255, 255), borderRadius: BorderRadius.circular(4)))),
          ]),
        );
      },
    );
  }
}
