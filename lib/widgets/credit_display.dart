import 'package:flutter/material.dart';
import '../config/theme.dart';

class CreditDisplay extends StatelessWidget {
  final int credits;

  const CreditDisplay({super.key, required this.credits});

  String _formatCredits(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}만';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}천';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.creditGold.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.creditGold.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on,
              color: AppTheme.creditGold, size: 18),
          const SizedBox(width: 4),
          Text(
            _formatCredits(credits),
            style: const TextStyle(
              color: AppTheme.creditGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
