import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';

class FocusSetupScreen extends StatefulWidget {
  const FocusSetupScreen({super.key});

  @override
  State<FocusSetupScreen> createState() => _FocusSetupScreenState();
}

class _FocusSetupScreenState extends State<FocusSetupScreen> {
  int _selectedMinutes = 60;
  String _selectedMode = 'normal';
  String _selectedTag = '기타';

  int _hours = 1;
  int _mins = 0;

  final _presetMinutes = [10, 25, 30, 45, 60, 90, 120];
  final _tags = ['수학', '영어', '국어', '과학', '사회', '코딩', '독서', '기타'];

  @override
  void initState() {
    super.initState();
    _syncFromMinutes(_selectedMinutes);
  }

  void _syncFromMinutes(int minutes) {
    _hours = minutes ~/ 60;
    _mins = minutes % 60;
  }

  int get _maxHours => AppConstants.maxFocusMinutes ~/ 60;

  void _syncToMinutes() {
    final total = _hours * 60 + _mins;
    _selectedMinutes = total.clamp(AppConstants.minFocusMinutes, AppConstants.maxFocusMinutes);
  }

  void _changeHours(int delta) {
    setState(() {
      _hours = (_hours + delta).clamp(0, _maxHours);
      if (_hours == 0 && _mins < 10) _mins = 10;
      _syncToMinutes();
    });
  }

  void _changeMins(int delta) {
    setState(() {
      final newMins = _mins + delta;
      if (newMins >= 60) {
        if (_hours < _maxHours) {
          _hours++;
          _mins = 0;
        }
      } else if (newMins < 0) {
        if (_hours > 0) {
          _hours--;
          _mins = 50;
        }
      } else {
        if (_hours >= _maxHours) {
          _mins = 0;
        } else {
          _mins = newMins;
        }
      }
      if (_hours == 0 && _mins < 10) _mins = 10;
      _syncToMinutes();
    });
  }

  void _selectPreset(int minutes) {
    setState(() {
      _selectedMinutes = minutes;
      _syncFromMinutes(minutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rawBase =
        (_selectedMinutes ~/ 10) * AppConstants.creditsPerTenMinutes;
    final baseCredits = _selectedMode == 'hardcore'
        ? (rawBase * AppConstants.hardcoreBonusRate).round()
        : rawBase;
    final endAdBonus = (baseCredits * AppConstants.endAdMultiplierRate).round();
    final expectedCredits =
        baseCredits + AppConstants.startAdBonus + endAdBonus;
    final expectedCreditsNoAd = baseCredits + endAdBonus;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '집중 설정',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 집중 시간 ──────────────────────────
            _buildSectionHeader(Icons.timer_outlined, '집중 시간', AppTheme.primaryColor),
            const SizedBox(height: 16),

            // 시간 조절 UI
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeUnit(
                    value: _hours,
                    label: '시간',
                    onIncrease: _hours < _maxHours ? () => _changeHours(1) : null,
                    onDecrease: _hours > 0 ? () => _changeHours(-1) : null,
                    onTap: () => _showInputDialog(isHour: true),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 22, left: 12, right: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _TimeUnit(
                    value: _mins,
                    label: '분',
                    onIncrease: () => _changeMins(10),
                    onDecrease: (_hours > 0 || _mins > 10)
                        ? () => _changeMins(-10)
                        : null,
                    onTap: () => _showInputDialog(isHour: false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 프리셋 칩
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetMinutes.map((minutes) {
                final isSelected = _selectedMinutes == minutes;
                return GestureDetector(
                  onTap: () => _selectPreset(minutes),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      color: isSelected ? null : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppTheme.borderMid,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 0,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      minutes >= 60
                          ? '${minutes ~/ 60}시간${minutes % 60 > 0 ? ' ${minutes % 60}분' : ''}'
                          : '$minutes분',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── 과목 태그 ──────────────────────────
            _buildSectionHeader(Icons.menu_book_outlined, '과목 태그', AppTheme.accentGreen),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = _selectedTag == tag;
                return GestureDetector(
                  onTap: () => setState(
                      () => _selectedTag = isSelected ? '기타' : tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentGreen.withValues(alpha: 0.15)
                          : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentGreen.withValues(alpha: 0.6)
                            : AppTheme.borderMid,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentGreen
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── 모드 선택 ──────────────────────────
            _buildSectionHeader(Icons.bolt, '모드 선택', AppTheme.secondaryColor),
            const SizedBox(height: 12),
            _buildModeCard(
              mode: 'normal',
              title: '일반 모드',
              description: '포기 시 진행 크레딧만 소멸',
              icon: Icons.shield_outlined,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            _buildModeCard(
              mode: 'hardcore',
              title: '하드코어 모드',
              description: '완료 시 크레딧 1.2배 · 포기 시 보유 크레딧 10% 차감',
              icon: Icons.local_fire_department,
              color: AppTheme.secondaryColor,
            ),

            const SizedBox(height: 28),

            // ── 예상 크레딧 ────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.creditGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.monetization_on,
                            color: AppTheme.creditGold, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '예상 크레딧',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildCreditRow(
                    '광고 보고 시작 시',
                    '$expectedCredits 크레딧',
                    AppTheme.creditGold,
                    isMain: true,
                    leadingIcon: Icons.play_circle_outline,
                  ),
                  const SizedBox(height: 8),
                  _buildCreditRow(
                    '그냥 시작 시',
                    '$expectedCreditsNoAd 크레딧',
                    AppTheme.textMuted,
                    isMain: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 시작 버튼 ──────────────────────────
            Container(
              decoration: AppTheme.glowButton,
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => _startFocus(context, watchAd: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '광고 보고 +${AppConstants.startAdBonus} 보너스 후 시작',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _startFocus(context, watchAd: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(
                      color: AppTheme.borderMid, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('그냥 시작하기', style: TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditRow(
      String label, String value, Color valueColor,
      {required bool isMain, IconData? leadingIcon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon,
                  size: 14,
                  color: isMain ? AppTheme.textSecondary : AppTheme.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isMain ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: isMain ? 14 : 13,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: isMain ? 18 : 14,
            fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Future<void> _showInputDialog({required bool isHour}) async {
    final controller = TextEditingController(
      text: isHour ? '$_hours' : '$_mins',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          isHour ? '시간 입력 (0~$_maxHours)' : '분 입력 (0, 10, 20...50)',
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 0;
              setState(() {
                if (isHour) {
                  _hours = v.clamp(0, _maxHours);
                } else {
                  _mins = ((v ~/ 10) * 10).clamp(0, 50);
                }
                if (_hours == 0 && _mins < 10) _mins = 10;
                _syncToMinutes();
              });
              Navigator.pop(ctx);
            },
            child: const Text('확인',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _startFocus(BuildContext context, {required bool watchAd}) {
    Navigator.of(context).pushNamed(
      AppRoutes.focus,
      arguments: {
        'focusMinutes': _selectedMinutes,
        'hardcoreMode': _selectedMode,
        'tag': _selectedTag,
        'watchAdOnStart': watchAd,
      },
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String description,
    required IconData icon,
    Color color = AppTheme.primaryColor,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? color : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// 시간/분 조절 단위 위젯
// ────────────────────────────────────────────
class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback onTap;

  const _TimeUnit({
    required this.value,
    required this.label,
    required this.onIncrease,
    required this.onDecrease,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onIncrease,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          color: onIncrease != null
              ? AppTheme.primaryColor
              : AppTheme.textMuted,
          iconSize: 32,
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderMid),
            ),
            child: Column(
              children: [
                Text(
                  value.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onDecrease,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          color: onDecrease != null
              ? AppTheme.primaryColor
              : AppTheme.textMuted,
          iconSize: 32,
        ),
      ],
    );
  }
}
