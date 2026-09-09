import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/ds_pressable.dart';

/// 로그인 — 워드마크 하나, 버튼 둘.
///
/// 배경 방사형 글로우와 그라디언트 로고는 걷어냈다. 첫 화면이 화려하면 그 뒤 화면이
/// 전부 심심해 보인다. 계기 모드 문법대로 조용하게 시작한다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _loginWithGoogle(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (success && context.mounted) _goNext(context, authProvider);
  }

  Future<void> _loginWithKakao(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithKakao();
    if (success && context.mounted) _goNext(context, authProvider);
  }

  void _goNext(BuildContext context, AuthProvider authProvider) {
    final route =
        authProvider.isNewUser ? AppRoutes.signupTerms : AppRoutes.home;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 3),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.flameTint,
                    borderRadius: R.rMd,
                  ),
                  child: Icon(Icons.local_fire_department_rounded,
                      size: 36, color: c.flame),
                ),
              ),
              const SizedBox(height: Sp.x6),
              Text(
                'Focus Cash',
                textAlign: TextAlign.center,
                style: DsType.display.on(c.textPrimary),
              ),
              const SizedBox(height: Sp.x2),
              Text(
                '집중한 시간이 크레딧이 됩니다',
                textAlign: TextAlign.center,
                style: DsType.body.on(c.textSecondary),
              ),
              const Spacer(flex: 4),
              if (authProvider.isLoading)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else ...<Widget>[
                _SocialButton(
                  onTap: () => _loginWithGoogle(context),
                  leading: const _GoogleMark(),
                  label: 'Google 로 계속하기',
                  background: Colors.white,
                  foreground: const Color(0xFF1F1F1F),
                  border: c.borderDefault,
                ),
                const SizedBox(height: Sp.x3),
                _SocialButton(
                  onTap: () => _loginWithKakao(context),
                  leading: const Icon(Icons.chat_bubble_rounded,
                      size: 18, color: Color(0xFF191919)),
                  label: '카카오로 계속하기',
                  background: const Color(0xFFFEE500),
                  foreground: const Color(0xFF191919),
                ),
              ],
              if (authProvider.error != null) ...<Widget>[
                const SizedBox(height: Sp.x3),
                Text(
                  authProvider.error!,
                  textAlign: TextAlign.center,
                  style: DsType.caption.on(c.danger),
                ),
              ],
              const SizedBox(height: Sp.x4),
              Text(
                '계속하면 이용약관과 개인정보 처리방침에 동의하는 것입니다',
                textAlign: TextAlign.center,
                style: DsType.micro.on(c.textTertiary),
              ),
              const SizedBox(height: Sp.x8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 소셜 로그인 버튼. 브랜드 가이드 색(구글 흰색, 카카오 노랑)은 그대로 둔다 —
/// 이 두 색은 우리 팔레트가 아니라 그들의 규정이다.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.onTap,
    required this.leading,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return DsPressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: background,
          borderRadius: R.rSm,
          border: border != null
              ? Border.all(color: border!, width: Stroke.hairline)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            leading,
            const SizedBox(width: Sp.x2 + 2),
            Text(label, style: DsType.bodyStrong.on(foreground)),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1,
      ),
    );
  }
}
