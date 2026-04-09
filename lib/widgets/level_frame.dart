import 'dart:math';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';

class LevelFrame extends StatefulWidget {
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
  State<LevelFrame> createState() => _LevelFrameState();
}

class _LevelFrameState extends State<LevelFrame> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  int get _grade => AppConstants.frameGradeForLevel(widget.level);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_grade >= 4) _spinController.repeat();
    if (_grade >= 3) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_grade == 0) return widget.child;

    final bgColor = AppTheme.of(context).bg;
    final innerChild = Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: ClipOval(child: widget.child),
    );

    Widget ring = _buildRing(innerChild, context);

    if (_grade >= 3) {
      ring = _wrapWithOrnaments(ring);
    }

    return ring;
  }

  // ── 링 빌더 ──────────────────────────────────────────────

  Widget _buildRing(Widget inner, BuildContext context) {
    switch (_grade) {
      case 1: return _buildBronze(inner);
      case 2: return _buildSilver(inner);
      case 3: return _buildGold(inner);
      case 4: return _buildIndigo(inner);
      case 5: return _buildLegend(inner);
      default: return widget.child;
    }
  }

  // 청동: 이중 링
  Widget _buildBronze(Widget inner) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFB45309).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB45309).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: widget.size - 8,
            height: widget.size - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB45309), width: 2.5),
            ),
          ),
          SizedBox(
            width: widget.size - 15,
            height: widget.size - 15,
            child: inner,
          ),
        ],
      ),
    );
  }

  // 실버: 코닉 그라디언트 링
  Widget _buildSilver(Widget inner) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFFCBD5E1),
            Color(0xFFF8FAFC),
            Color(0xFF94A3B8),
            Color(0xFFE2E8F0),
            Color(0xFFF8FAFC),
            Color(0xFF94A3B8),
            Color(0xFFCBD5E1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(3.5),
      child: inner,
    );
  }

  // 골드: 코닉 그라디언트 + 맥동 글로우는 _wrapWithOrnaments에서 처리
  Widget _buildGold(Widget inner) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFFFD60A),
            Color(0xFFFBBF24),
            Color(0xFFB45309),
            Color(0xFFF59E0B),
            Color(0xFFFFD60A),
            Color(0xFFB45309),
            Color(0xFFF59E0B),
          ],
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: inner,
    );
  }

  // 인디고: 회전 스윕 그라디언트
  Widget _buildIndigo(Widget inner) {
    return AnimatedBuilder(
      animation: _spinController,
      builder: (_, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: const [
              Color(0xFF4F46E5),
              Color(0xFF818CF8),
              Color(0xFF06B6D4),
              Color(0xFF818CF8),
              Color(0xFF4F46E5),
            ],
            transform: GradientRotation(_spinController.value * 2 * pi),
          ),
        ),
        padding: const EdgeInsets.all(4.5),
        child: child,
      ),
      child: inner,
    );
  }

  // 전설: 레인보우 회전 그라디언트
  Widget _buildLegend(Widget inner) {
    return AnimatedBuilder(
      animation: _spinController,
      builder: (_, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: const [
              Color(0xFF4F46E5),
              Color(0xFF06B6D4),
              Color(0xFF10B981),
              Color(0xFFF59E0B),
              Color(0xFFEC4899),
              Color(0xFF4F46E5),
            ],
            transform: GradientRotation(_spinController.value * 2 * pi),
          ),
        ),
        padding: const EdgeInsets.all(5.5),
        child: child,
      ),
      child: inner,
    );
  }

  // ── 장식 래퍼 (grade 3+) ─────────────────────────────────

  Widget _wrapWithOrnaments(Widget ring) {
    const double pad = 12.0;
    final double total = widget.size + pad * 2;

    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          _buildPulseGlow(total),
          ring,
          if (_grade == 3) ..._buildStarOrnaments(total),
          if (_grade == 4) ..._buildGemOrnaments(total),
          if (_grade == 5) ..._buildOrbitingDots(total),
        ],
      ),
    );
  }

  // 맥동 글로우
  Widget _buildPulseGlow(double total) {
    final Color glowColor = switch (_grade) {
      3 => const Color(0xFFF59E0B),
      4 => const Color(0xFF4F46E5),
      _ => const Color(0xFF06B6D4),
    };

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        width: total,
        height: total,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: _pulseAnim.value),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // Grade 3: ★ 4방향
  List<Widget> _buildStarOrnaments(double total) {
    final double c = total / 2;
    final double r = widget.size / 2;
    final offsets = [
      Offset(c, c - r),
      Offset(c, c + r),
      Offset(c - r, c),
      Offset(c + r, c),
    ];
    return List.generate(4, (i) => Positioned(
      left: offsets[i].dx - 8,
      top: offsets[i].dy - 8,
      child: _TwinklingStar(delay: i * 375),
    ));
  }

  // Grade 4: ◆ 4방향
  List<Widget> _buildGemOrnaments(double total) {
    final double c = total / 2;
    final double r = widget.size / 2;
    final offsets = [
      Offset(c, c - r),
      Offset(c, c + r),
      Offset(c - r, c),
      Offset(c + r, c),
    ];
    return List.generate(4, (i) => Positioned(
      left: offsets[i].dx - 6,
      top: offsets[i].dy - 6,
      child: Transform.rotate(
        angle: pi / 4,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF818CF8), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.9),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    ));
  }

  // Grade 5: 8개 공전 도트
  List<Widget> _buildOrbitingDots(double total) {
    final List<Color> colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF06B6D4),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFF818CF8),
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
    ];
    final double c = total / 2;
    final double r = widget.size / 2 + 2.0;

    return List.generate(8, (i) {
      final startAngle = i * pi / 4;
      return AnimatedBuilder(
        animation: _spinController,
        builder: (_, __) {
          final angle = startAngle + _spinController.value * 2 * pi;
          return Positioned(
            left: c + r * cos(angle) - 3.5,
            top: c + r * sin(angle) - 3.5,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors[i],
                boxShadow: [
                  BoxShadow(color: colors[i].withValues(alpha: 0.9), blurRadius: 6),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

// ── 깜빡이는 별 위젯 ─────────────────────────────────────────

class _TwinklingStar extends StatefulWidget {
  final int delay;
  const _TwinklingStar({required this.delay});

  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _anim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          '★',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFFFFD60A),
            shadows: [Shadow(color: Color(0xFFF59E0B), blurRadius: 10)],
          ),
        ),
      ),
    );
  }
}

// ── 레벨 배지 ────────────────────────────────────────────────

class LevelBadge extends StatelessWidget {
  final int level;
  final bool compact;

  const LevelBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final grade = AppConstants.frameGradeForLevel(level);
    final color = _colorForGrade(grade, context);
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

  Color _colorForGrade(int grade, BuildContext context) {
    switch (grade) {
      case 1: return const Color(0xFFB45309);
      case 2: return const Color(0xFF94A3B8);
      case 3: return AppTheme.rankGold;
      case 4: return AppTheme.primaryColor;
      case 5: return AppTheme.secondaryColor;
      default: return AppTheme.of(context).textMuted;
    }
  }
}
