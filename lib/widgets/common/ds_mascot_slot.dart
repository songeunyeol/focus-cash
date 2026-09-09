import 'package:flutter/material.dart';

/// 마스코트가 들어갈 자리.
///
/// 오늘 집중이 0분일 때만 다이얼 가운데에 나타난다. 보여줄 숫자가 `00:00` 뿐인
/// 순간이라 데이터와 자리를 다투지 않고, 등장 자체가 "아직 시작 전"이라는 정보가 된다.
///
/// 브랜드 확정 자산: `assets/images/mascot_front.png`.
class DsMascotSlot extends StatelessWidget {
  const DsMascotSlot({super.key, this.size = 96});

  final double size;

  static const String assetPath = 'assets/images/mascot_front.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'FocusCash 마스코트',
      ),
    );
  }
}
