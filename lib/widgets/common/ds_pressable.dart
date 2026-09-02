import 'package:flutter/material.dart';

import '../../design/ds.dart';

/// 누름 피드백을 불투명도로 표현한다.
///
/// 색을 바꾸는 대신 opacity 를 떨어뜨리는 것이 이 디자인 시스템의 규칙이다.
/// 단일 액센트 체계에서는 "눌리면 색이 바뀐다"를 표현할 여벌 색이 없기도 하고,
/// 잉크 스플래시는 정밀 계기 톤과 맞지 않는다.
class DsPressable extends StatefulWidget {
  const DsPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedOpacity = Motion.pressedOpacity,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedOpacity;
  final HitTestBehavior behavior;

  @override
  State<DsPressable> createState() => _DsPressableState();
}

class _DsPressableState extends State<DsPressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null;

  void _set(bool v) {
    if (!_enabled || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedOpacity(
        opacity: _down ? widget.pressedOpacity : 1,
        duration: Motion.micro,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}
