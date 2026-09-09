import 'package:flutter/material.dart';

import '../design/ds.dart';

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
    final DsColors c = context.ds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x1 + 2),
      decoration: DsSurface.tint(c, c.flameTint, radius: R.rPill, border: true),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.monetization_on, color: c.flame, size: 16),
          const SizedBox(width: Sp.x1),
          Text(
            _formatCredits(credits),
            style: DsType.label.on(c.accentText).tnum,
          ),
        ],
      ),
    );
  }
}
