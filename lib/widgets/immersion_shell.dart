import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/ds.dart';
import '../domain/immersion_rules.dart';

/// 몰입 모드 껍데기 — 집중 화면의 "집중 중" 뷰를 감싼다.
///
/// 15초 무조작이면 [child] 를 **트리에서 제거**하고 순수 검정 화면에 타이머만 남긴다.
/// 배너 광고를 "가리는" 게 아니라 위젯 자체가 사라지므로 광고 SDK 도 그리기를 멈춘다.
/// 아무 곳이나 누르면 즉시 원래 화면으로 돌아온다.
///
/// 시스템 UI(상태바·내비바)는 몰입 중에만 immersiveSticky 로 숨기고, 나갈 때 edgeToEdge 로 복원한다.
/// 화면 밝기 저하는 플랫폼 채널이 필요해 이 골격에는 없다 (TODO: screen_brightness 도입 시 여기서).
class ImmersionShell extends StatefulWidget {
  const ImmersionShell({
    super.key,
    required this.remainingSeconds,
    required this.child,
    this.enabled = true,
    this.caption,
    this.onModeChanged,
  });

  /// 몰입 화면에 표시할 잔여 초. 매 틱 갱신되는 값을 그대로 넘긴다.
  final int remainingSeconds;

  /// 몰입이 아닐 때 보여줄 원래 화면.
  final Widget child;

  /// 설정에서 끈 경우 false.
  final bool enabled;

  /// 타이머 아래 한 줄 (예: 과목 태그). 없으면 표시하지 않는다.
  final String? caption;

  /// 진입/이탈 알림 (분석 이벤트용).
  final ValueChanged<bool>? onModeChanged;

  @override
  State<ImmersionShell> createState() => _ImmersionShellState();
}

class _ImmersionShellState extends State<ImmersionShell> {
  final DateTime _shownAt = DateTime.now();
  DateTime? _lastInteraction;
  Timer? _ticker;
  bool _immersed = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void didUpdateWidget(covariant ImmersionShell old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _immersed) _exit();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_immersed) _restoreSystemUi();
    super.dispose();
  }

  void _check() {
    if (!mounted || _immersed) return;
    final bool enter = ImmersionRules.shouldEnter(
      enabled: widget.enabled,
      now: DateTime.now(),
      screenShownAt: _shownAt,
      lastInteraction: _lastInteraction,
    );
    if (enter) _enter();
  }

  void _enter() {
    setState(() => _immersed = true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.onModeChanged?.call(true);
  }

  void _exit() {
    _lastInteraction = DateTime.now();
    if (!_immersed) return;
    setState(() => _immersed = false);
    _restoreSystemUi();
    widget.onModeChanged?.call(false);
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _touched(PointerEvent _) {
    if (_immersed) {
      _exit();
    } else {
      _lastInteraction = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener 는 자식이 이벤트를 소비해도 호출된다 — 버튼을 눌러도 "조작"으로 센다.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _touched,
      child: AnimatedSwitcher(
        duration: Motion.page,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _immersed
            ? _ImmersionView(
                key: const ValueKey<String>('immersion'),
                remainingSeconds: widget.remainingSeconds,
                caption: widget.caption,
              )
            : KeyedSubtree(
                key: const ValueKey<String>('normal'),
                child: widget.child,
              ),
      ),
    );
  }
}

/// 순수 검정 + 저휘도 타이머. 링·버튼·광고 없음.
class _ImmersionView extends StatelessWidget {
  const _ImmersionView({
    super.key,
    required this.remainingSeconds,
    this.caption,
  });

  final int remainingSeconds;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return DsModeScope(
      mode: DsMode.immersion,
      child: ColoredBox(
        color: c.voidBlack,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                ImmersionRules.timerLabel(remainingSeconds),
                style: DsType.timerDisplay.dim(c.textDim),
              ),
              if (caption != null && caption!.isNotEmpty) ...<Widget>[
                const SizedBox(height: Sp.x3),
                Text(caption!, style: DsType.caption.dim(c.textDim)),
              ],
              const SizedBox(height: Sp.x12),
              Text('화면을 누르면 돌아갑니다',
                  style: DsType.micro.dim(c.textDim)),
            ],
          ),
        ),
      ),
    );
  }
}
