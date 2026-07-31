import 'package:flutter/cupertino.dart';
import 'package:sime/main.dart';

class AffectionBar extends StatelessWidget {
  final double affection;
  const AffectionBar({super.key, required this.affection});

  @override
  Widget build(BuildContext context) {
    final clamped = affection.clamp(0.0, 100.0);
    final ratio = clamped / 100.0;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFE8E8E8)),
                  FractionallySizedBox(widthFactor: ratio, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [_barColor(clamped), _barColor(clamped).withAlpha(180)])))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${clamped.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontFamily: 'SF Mono')),
      ],
    );
  }

  Color _barColor(double value) {
    if (value < 30) return const Color(0xFFFF453A);
    if (value < 50) return const Color(0xFFFF9F0A);
    if (value < 70) return const Color(0xFF64D2FF);
    if (value < 90) return const Color(0xFF7B8CDE);
    return const Color(0xFFAC8CFF);
  }
}
