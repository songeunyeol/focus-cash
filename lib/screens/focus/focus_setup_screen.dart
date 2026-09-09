import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/ds_button.dart';

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

  final List<int> _presetMinutes = <int>[10, 25, 30, 45, 60, 90, 120];
  final List<String> _tags = <String>[
    '수학',
    '영어',
    '국어',
    '과학',
    '사회',
    '코딩',
    '독서',
    '기타'
  ];

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
    final int total = _hours * 60 + _mins;
    _selectedMinutes = total.clamp(
        AppConstants.minFocusMinutes, AppConstants.maxFocusMinutes);
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
      final int newMins = _mins + delta;
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
    final DsColors c = context.ds;
    final int rawBase =
        (_selectedMinutes ~/ 10) * AppConstants.creditsPerTenMinutes;
    final int baseCredits = _selectedMode == 'hardcore'
        ? (rawBase * AppConstants.hardcoreBonusRate).round()
        : rawBase;
    final int endAdBonus =
        (baseCredits * AppConstants.endAdMultiplierRate).round();
    final int expectedCredits =
        baseCredits + AppConstants.startAdBonus + endAdBonus;
    final int expectedCreditsNoAd = baseCredits + endAdBonus;

    final int todayCredits =
        context.watch<AuthProvider>().user?.todayCredits ?? 0;
    final int capRemaining =
        (AppConstants.dailyCreditCap - todayCredits)
            .clamp(0, AppConstants.dailyCreditCap);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('집중 설정')),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(Sp.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('집중 시간', style: DsType.subhead.on(c.textPrimary)),
            const SizedBox(height: Sp.x4),
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: Sp.x6, horizontal: Sp.x4),
              decoration: DsSurface.e1(c, radius: R.rLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _TimeUnit(
                    value: _hours,
                    label: '시간',
                    onIncrease:
                        _hours < _maxHours ? () => _changeHours(1) : null,
                    onDecrease: _hours > 0 ? () => _changeHours(-1) : null,
                    onTap: () => _showInputDialog(isHour: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: 22, left: Sp.x3, right: Sp.x3),
                    child: Text(':', style: DsType.display.on(c.textSecondary)),
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
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: _presetMinutes.map((int minutes) {
                final bool isSelected = _selectedMinutes == minutes;
                final String label = minutes >= 60
                    ? '${minutes ~/ 60}시간${minutes % 60 > 0 ? ' ${minutes % 60}분' : ''}'
                    : '$minutes분';
                return _SelectChip(
                  label: label,
                  selected: isSelected,
                  onTap: () => _selectPreset(minutes),
                );
              }).toList(),
            ),
            const SizedBox(height: Sp.x8),
            Text('과목 태그', style: DsType.subhead.on(c.textPrimary)),
            const SizedBox(height: Sp.x3),
            Wrap(
              spacing: Sp.x2,
              runSpacing: Sp.x2,
              children: _tags.map((String tag) {
                final bool isSelected = _selectedTag == tag;
                return _SelectChip(
                  label: tag,
                  selected: isSelected,
                  onTap: () => setState(
                      () => _selectedTag = isSelected ? '기타' : tag),
                );
              }).toList(),
            ),
            const SizedBox(height: Sp.x8),
            Text('모드', style: DsType.subhead.on(c.textPrimary)),
            const SizedBox(height: Sp.x3),
            _ModeCard(
              selected: _selectedMode == 'normal',
              title: '일반 모드',
              description: '포기 시 진행 크레딧만 소멸',
              icon: Icons.shield_outlined,
              onTap: () => setState(() => _selectedMode = 'normal'),
            ),
            const SizedBox(height: Sp.x2),
            _ModeCard(
              selected: _selectedMode == 'hardcore',
              title: '하드코어 모드',
              description: '완료 시 크레딧 1.2배 · 포기 시 보유 크레딧 10% 차감',
              icon: Icons.local_fire_department,
              onTap: () => setState(() => _selectedMode = 'hardcore'),
            ),
            const SizedBox(height: Sp.x8),
            Container(
              padding: const EdgeInsets.all(Sp.x4),
              decoration: DsSurface.e1(c),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.monetization_on, color: c.flame, size: 20),
                      const SizedBox(width: Sp.x2),
                      Text('예상 크레딧', style: DsType.bodyStrong.on(c.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: Sp.x3),
                  _CreditRow(
                    label: '광고 보고 시작 시',
                    value: '$expectedCredits 크레딧',
                    emphasize: true,
                  ),
                  const SizedBox(height: Sp.x2),
                  _CreditRow(
                    label: '그냥 시작 시',
                    value: '$expectedCreditsNoAd 크레딧',
                    emphasize: false,
                  ),
                  if (capRemaining < expectedCredits) ...<Widget>[
                    const SizedBox(height: Sp.x3),
                    Text(
                      capRemaining <= 0
                          ? '오늘 적립 한도 ${AppConstants.dailyCreditCap}크레딧을 모두 채웠어요. 기록과 XP는 계속 쌓여요.'
                          : '오늘 적립 한도까지 $capRemaining크레딧 남았어요.',
                      style: DsType.caption.on(c.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Sp.x6),
            DsButton(
              label: '광고 보고 +${AppConstants.startAdBonus} 보너스 후 시작',
              icon: Icons.play_circle_outline,
              size: DsButtonSize.hero,
              onPressed: () => _startFocus(context, watchAd: true),
            ),
            const SizedBox(height: Sp.x2),
            DsButton(
              label: '그냥 시작하기',
              variant: DsButtonVariant.quiet,
              onPressed: () => _startFocus(context, watchAd: false),
            ),
            const SizedBox(height: Sp.x6),
          ],
        ),
      ),
    );
  }

  Future<void> _showInputDialog({required bool isHour}) async {
    final TextEditingController controller = TextEditingController(
      text: isHour ? '$_hours' : '$_mins',
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        final DsColors c = ctx.ds;
        return AlertDialog(
          backgroundColor: c.surfaceRaised,
          shape: const RoundedRectangleBorder(borderRadius: R.rLg),
          title: Text(
            isHour ? '시간 입력 (0~$_maxHours)' : '분 입력 (0, 10, 20...50)',
            style: DsType.bodyStrong.on(c.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            autofocus: true,
            style: DsType.display.on(c.textPrimary).tnum,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.flame),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: c.flame, width: Stroke.thick),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('취소', style: DsType.body.on(c.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final int v = int.tryParse(controller.text) ?? 0;
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
              child: Text('확인', style: DsType.bodyStrong.on(c.accentText)),
            ),
          ],
        );
      },
    );
  }

  void _startFocus(BuildContext context, {required bool watchAd}) {
    Navigator.of(context).pushNamed(
      AppRoutes.focus,
      arguments: <String, Object>{
        'focusMinutes': _selectedMinutes,
        'hardcoreMode': _selectedMode,
        'tag': _selectedTag,
        'watchAdOnStart': watchAd,
      },
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.standard,
        padding:
            const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x2),
        decoration: BoxDecoration(
          color: selected ? c.flame : c.surface,
          borderRadius: R.rSm,
          border: Border.all(
            color: selected ? c.flame : c.borderDefault,
            width: Stroke.hairline,
          ),
        ),
        child: Text(
          label,
          style: DsType.label.on(selected ? c.onAccent : c.textSecondary),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.standard,
        padding: Sp.card,
        decoration: DsSurface.of(
          c,
          DsElevation.e1,
          tone: selected ? c.flameTint : null,
          borderColor: selected ? c.flame : null,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: DsSurface.tint(c, c.flameTint, radius: R.rMd),
              child: Icon(icon, color: c.flame, size: 22),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: DsType.bodyStrong
                        .on(selected ? c.accentText : c.textPrimary),
                  ),
                  const SizedBox(height: Sp.x1),
                  Text(description, style: DsType.caption.on(c.textSecondary)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: c.flame, size: 22),
          ],
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: DsType.caption
              .on(emphasize ? c.textSecondary : c.textTertiary),
        ),
        Text(
          value,
          style: (emphasize ? DsType.subhead : DsType.body)
              .on(emphasize ? c.accentText : c.textTertiary)
              .tnum,
        ),
      ],
    );
  }
}

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({
    required this.value,
    required this.label,
    required this.onIncrease,
    required this.onDecrease,
    required this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Column(
      children: <Widget>[
        IconButton(
          onPressed: onIncrease,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
          color: onIncrease != null ? c.flame : c.textDisabled,
          iconSize: 32,
        ),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88,
            padding: const EdgeInsets.symmetric(
                horizontal: Sp.x3, vertical: Sp.x2),
            decoration: DsSurface.e1(c),
            child: Column(
              children: <Widget>[
                Text(
                  value.toString().padLeft(2, '0'),
                  style: DsType.display.on(c.textPrimary).tnum,
                  textAlign: TextAlign.center,
                ),
                Text(label, style: DsType.caption.on(c.textTertiary)),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onDecrease,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          color: onDecrease != null ? c.flame : c.textDisabled,
          iconSize: 32,
        ),
      ],
    );
  }
}
