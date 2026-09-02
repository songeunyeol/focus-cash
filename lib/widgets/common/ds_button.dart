import 'package:flutter/material.dart';

import '../../design/ds.dart';
import 'ds_pressable.dart';

enum DsButtonVariant {
  /// 액센트로 채운 면. 한 화면에 하나만 쓴다.
  primary,

  /// 선만. 액센트 예산을 아껴야 할 때.
  quiet,

  /// 배경도 선도 없음.
  ghost,
}

enum DsButtonSize { md, hero }

/// 기본 버튼.
///
/// 둥근 알약(radius 999)이 아니라 [R.sm] 각진 면을 기본으로 쓴다.
/// 알약은 소비자 앱의 문법이고 각진 면은 도구의 문법인데, 이 앱의 계기 모드는 후자다.
/// 다만 보상 모드([DsMode.reward]) 안에서는 자동으로 pill 로 바뀐다 —
/// 축하하는 순간에는 규칙이 반대여야 한다.
class DsButton extends StatelessWidget {
  const DsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.icon,
    this.trailing,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? icon;

  /// 오른쪽 끝 요소. 보통 화살표.
  final Widget? trailing;
  final bool expand;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final bool reward = context.dsMode.isReward;
    final BorderRadius radius = reward ? R.rPill : R.rSm;

    final Color fg = switch (variant) {
      DsButtonVariant.primary => c.onAccent,
      DsButtonVariant.quiet => c.flame,
      DsButtonVariant.ghost => c.textSecondary,
    };

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          trailing == null ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: _enabled ? fg : c.textDisabled),
              const SizedBox(width: Sp.x2),
            ],
            Text(
              label,
              style: (reward ? DsType.bodyStrong : DsType.bodyStrong)
                  .on(_enabled ? fg : c.textDisabled)
                  .copyWith(fontWeight: reward ? FontWeight.w700 : FontWeight.w600),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );

    return DsPressable(
      onTap: onPressed,
      child: Container(
        width: expand ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: Sp.x4,
          vertical: size == DsButtonSize.hero ? Sp.x4 : Sp.x3,
        ),
        decoration: BoxDecoration(
          color: variant == DsButtonVariant.primary
              ? (_enabled ? c.flame : c.surfaceOverlay)
              : null,
          borderRadius: radius,
          border: variant == DsButtonVariant.quiet
              ? Border.all(
                  color: _enabled ? c.flame : c.borderDefault,
                  width: Stroke.hairline,
                )
              : null,
        ),
        child: content,
      ),
    );
  }
}
