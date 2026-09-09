import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/ds_button.dart';

/// 가입 완료 — 보상 모드의 첫 순간.
///
/// 이 화면만 [DsMode.reward] 로 감싼다. 축하는 여기서 하고, 다음 화면(홈)은 다시 조용하다.
/// 그라디언트·글로우 대신 스케일 인 + 액센트 틴트 면으로 "순간"을 만든다.
class SignupCompleteScreen extends StatefulWidget {
  const SignupCompleteScreen({super.key});

  @override
  State<SignupCompleteScreen> createState() => _SignupCompleteScreenState();
}

class _SignupCompleteScreenState extends State<SignupCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final user = context.read<AuthProvider>().user;
    final String nickname =
        (user?.displayName.isNotEmpty ?? false) ? user!.displayName : '집중러';

    return DsModeScope(
      mode: DsMode.reward,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Spacer(flex: 3),
                ScaleTransition(
                  scale: _scale,
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: c.flame,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 52, color: c.onAccent),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.x8),
                FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: <Widget>[
                      Text(
                        '$nickname 님, 준비됐어요',
                        textAlign: TextAlign.center,
                        style: DsType.title.on(c.textPrimary),
                      ),
                      const SizedBox(height: Sp.x3),
                      Text(
                        '가입이 끝났습니다.\n첫 집중을 완료하면 보너스가 지급됩니다.',
                        textAlign: TextAlign.center,
                        style: DsType.body.on(c.textSecondary),
                      ),
                      const SizedBox(height: Sp.x8),
                      Container(
                        padding: Sp.card,
                        decoration: DsSurface.tint(c, c.flameTint,
                            radius: R.rMd, border: true),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.card_giftcard_rounded,
                                color: c.flame, size: 28),
                            const SizedBox(width: Sp.x4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('첫 집중 완료 보너스',
                                      style: DsType.caption
                                          .on(c.textSecondary)),
                                  const SizedBox(height: Sp.x1),
                                  Text(
                                    '+${AppConstants.firstFocusBonus} 크레딧',
                                    style: DsType.heading
                                        .on(c.accentText)
                                        .tnum,
                                  ),
                                  const SizedBox(height: Sp.x1),
                                  Text('10분만 집중해도 받을 수 있어요',
                                      style: DsType.micro
                                          .on(c.textTertiary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 4),
                DsButton(
                  label: '집중 시작하기',
                  size: DsButtonSize.hero,
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.home),
                ),
                const SizedBox(height: Sp.x6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
