import 'package:flutter/material.dart';

import '../../design/ds.dart';

/// 마스코트가 들어갈 자리.
///
/// 오늘 집중이 0분일 때만 다이얼 가운데에 나타난다. 보여줄 숫자가 `00:00` 뿐인
/// 순간이라 데이터와 자리를 다투지 않고, 등장 자체가 "아직 시작 전"이라는 정보가 된다.
/// 늘 떠 있으면 일주일 만에 벽지가 되고 무엇에도 반응할 수 없게 된다.
///
/// 지금은 앱 아이콘과 같은 기하로 그린 자리 표시다. 캐릭터 시안이 나오면
/// [build] 의 CustomPaint 를 `Image.asset(...)` 하나로 바꾸면 된다.
class DsMascotSlot extends StatelessWidget {
  const DsMascotSlot({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return SizedBox(
      width: size,
      height: size * 1.1,
      child: CustomPaint(
        painter: _FlamePainter(
          outer: c.flameDim,
          inner: c.flame,
          face: c.bg,
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.outer, required this.inner, required this.face});

  final Color outer;
  final Color inner;
  final Color face;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 바깥 불꽃 — 둥근 바닥에서 갈고리처럼 휜 끝으로
    final Path shell = Path()
      ..moveTo(w * .50, h * .05)
      ..cubicTo(w * .70, h * .28, w * .84, h * .42, w * .84, h * .60)
      ..arcToPoint(Offset(w * .16, h * .60),
          radius: Radius.circular(w * .34), clockwise: true)
      ..cubicTo(w * .16, h * .42, w * .30, h * .28, w * .50, h * .05)
      ..close();

    // 안쪽 불꽃
    final Path core = Path()
      ..moveTo(w * .50, h * .40)
      ..cubicTo(w * .60, h * .53, w * .67, h * .59, w * .67, h * .67)
      ..arcToPoint(Offset(w * .33, h * .67),
          radius: Radius.circular(w * .17), clockwise: true)
      ..cubicTo(w * .33, h * .59, w * .40, h * .53, w * .50, h * .40)
      ..close();

    canvas
      ..drawPath(shell, Paint()..color = outer.withValues(alpha: .55))
      ..drawPath(core, Paint()..color = inner.withValues(alpha: .55));

    // 감은 눈 — 자고 있다
    final Paint eye = Paint()
      ..color = face.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .035
      ..strokeCap = StrokeCap.round;

    for (final double cx in <double>[w * .40, w * .60]) {
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(cx, h * .655), width: w * .13, height: w * .10),
        0,
        3.14159,
        false,
        eye,
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.outer != outer || old.inner != inner || old.face != face;
}
