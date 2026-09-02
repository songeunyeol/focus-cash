import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/ds.dart';

/// 계기 다이얼.
///
/// 굵은 원호 하나로 진행을 그리면 어느 앱에나 있는 프로그레스 링이 된다.
/// 눈금 60개가 하나씩 채워지는 형태여야 "계기"로 읽히고, 정밀함이 장식이 아니라
/// 구조에서 나온다. 60개인 것은 분(分)의 은유이기도 하다.
class DsDial extends StatelessWidget {
  const DsDial({
    super.key,
    required this.progress,
    this.size = 214,
    this.child,
    this.tickCount = 60,
    this.tickLength = 8,
    this.tickWidth = 1.2,
  });

  /// 0.0 ~ 1.0. 범위를 벗어나면 잘라서 쓴다.
  final double progress;
  final double size;
  final Widget? child;
  final int tickCount;
  final double tickLength;
  final double tickWidth;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(
          progress: progress.clamp(0.0, 1.0),
          off: c.borderStrong,
          on: c.flame,
          tickCount: tickCount,
          tickLength: tickLength,
          tickWidth: tickWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.progress,
    required this.off,
    required this.on,
    required this.tickCount,
    required this.tickLength,
    required this.tickWidth,
  });

  final double progress;
  final Color off;
  final Color on;
  final int tickCount;
  final double tickLength;
  final double tickWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double outer = size.shortestSide / 2;
    final double inner = outer - tickLength;

    final Paint paint = Paint()
      ..strokeWidth = tickWidth
      // round cap 은 눈금을 굵은 대시로 보이게 한다. 계기의 선은 각져야 한다.
      ..strokeCap = StrokeCap.butt;

    // 12시 방향에서 시작해 시계 방향으로
    const double start = -math.pi / 2;
    final double step = (2 * math.pi) / tickCount;
    final int litCount = (tickCount * progress).round();

    for (int i = 0; i < tickCount; i++) {
      final double a = start + i * step;
      final double dx = math.cos(a);
      final double dy = math.sin(a);
      paint.color = i < litCount ? on : off;
      canvas.drawLine(
        center + Offset(dx * inner, dy * inner),
        center + Offset(dx * outer, dy * outer),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress ||
      old.off != off ||
      old.on != on ||
      old.tickCount != tickCount;
}
