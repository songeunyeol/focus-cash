import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';

/// 레벨에 따라 아바타 주위에 프레임(테두리+글로우)을 그려주는 위젯
class LevelFrame extends StatelessWidget {
  final int level;
  final double size;
  final Widget child;

  const LevelFrame({
    super.key,
    required this.level,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final grade = AppConstants.frameGradeForLevel(level);
    if (grade == 0) return child; // 레벨 1~4: 프레임 없음

    final frameInfo = _frameInfoForGrade(grade);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: frameInfo.gradient,
        color: frameInfo.gradient == null ? frameInfo.color : null,
        boxShadow: [
          BoxShadow(
            color: frameInfo.glowColor.withValues(alpha: 0.5),
            blurRadius: frameInfo.glowRadius,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.all(frameInfo.borderWidth),
      child: child,
    );
  }

  _FrameInfo _frameInfoForGrade(int grade) {
    switch (grade) {
      case 1: // 청동 (lv 5~9)
        return _FrameInfo(
          color: const Color(0xFFB45309),
          glowColor: const Color(0xFFB45309),
          borderWidth: 2.5,
          glowRadius: 10,
        );
      case 2: // 실버 (lv 10~19)
        return _FrameInfo(
          color: const Color(0xFF94A3B8),
          glowColor: const Color(0xFF94A3B8),
          borderWidth: 3,
          glowRadius: 14,
        );
      case 3: // 골드 (lv 20~29)
        return _FrameInfo(
          color: AppTheme.rankGold,
          glowColor: AppTheme.rankGold,
          borderWidth: 3,
          glowRadius: 18,
        );
      case 4: // 인디고 (lv 30~49)
        return _FrameInfo(
          color: AppTheme.primaryColor,
          glowColor: AppTheme.primaryColor,
          borderWidth: 3.5,
          glowRadius: 22,
        );
      case 5: // 그라디언트 (lv 50+)
        return _FrameInfo(
          gradient: AppTheme.primaryGradient,
          glowColor: AppTheme.secondaryColor,
          borderWidth: 4,
          glowRadius: 28,
        );
      default:
        return _FrameInfo(
          color: AppTheme.borderMid,
          glowColor: Colors.transparent,
          borderWidth: 1,
          glowRadius: 0,
        );
    }
  }
}

class _FrameInfo {
  final Color color;
  final Color glowColor;
  final double borderWidth;
  final double glowRadius;
  final Gradient? gradient;

  _FrameInfo({
    this.color = Colors.transparent,
    required this.glowColor,
    required this.borderWidth,
    required this.glowRadius,
    this.gradient,
  });
}

/// 레벨 배지 (아바타 아래에 표시하는 작은 칩)
class LevelBadge extends StatelessWidget {
  final int level;
  final bool compact;

  const LevelBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final grade = AppConstants.frameGradeForLevel(level);
    final color = _colorForGrade(grade);
    final title = compact ? 'Lv.$level' : 'Lv.$level  ${AppConstants.titleForLevel(level)}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _colorForGrade(int grade) {
    switch (grade) {
      case 1: return const Color(0xFFB45309);
      case 2: return const Color(0xFF94A3B8);
      case 3: return AppTheme.rankGold;
      case 4: return AppTheme.primaryColor;
      case 5: return AppTheme.secondaryColor;
      default: return AppTheme.textMuted;
    }
  }
}
