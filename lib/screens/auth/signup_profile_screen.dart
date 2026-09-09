import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/ds_button.dart';
import '../../widgets/common/ds_pressable.dart';

/// 프로필 설정 — 아바타·닉네임·초대 코드.
class SignupProfileScreen extends StatefulWidget {
  const SignupProfileScreen({super.key});

  @override
  State<SignupProfileScreen> createState() => _SignupProfileScreenState();
}

class _SignupProfileScreenState extends State<SignupProfileScreen> {
  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _inviteCode = TextEditingController();
  int _selectedAvatar = 0;
  bool _isLoading = false;

  // 앱 전역과 같은 목록이어야 한다. 별도 리스트를 쓰던 시절엔 가입 때 고른
  // 아바타(📚)가 이후 화면에서 다른 동물(🦁)로 보였다.
  static const List<String> _avatars = AppConstants.avatarEmojis;

  static const int _minNickname = 2;
  static const int _maxNickname = 10;
  static const int _inviteCodeLength = 8;

  @override
  void dispose() {
    _nickname.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _complete() async {
    final String nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      _snack('닉네임을 입력해 주세요');
      return;
    }
    if (nickname.length < _minNickname || nickname.length > _maxNickname) {
      _snack('닉네임은 $_minNickname~$_maxNickname자로 입력해 주세요');
      return;
    }

    setState(() => _isLoading = true);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final bool marketingAgreed = args?['marketingAgreed'] as bool? ?? false;

    try {
      await context.read<AuthProvider>().completeSignup(
            displayName: nickname,
            avatarIndex: _selectedAvatar,
            marketingAgreed: marketingAgreed,
            inviteCodeUsed: _inviteCode.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.signupComplete);
      }
    } catch (e) {
      debugPrint('가입 완료 실패: $e');
      if (mounted) {
        _snack('가입을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('프로필 설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x4, Sp.x6, Sp.x8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '랭킹에 표시될 닉네임과 아바타를 골라 주세요',
                style: DsType.body.on(c.textSecondary),
              ),
              const SizedBox(height: Sp.x8),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.flame, width: Stroke.thick),
                  ),
                  child: Center(
                    child: Text(_avatars[_selectedAvatar],
                        style: const TextStyle(fontSize: 46)),
                  ),
                ),
              ),
              const SizedBox(height: Sp.x6),
              _SectionLabel('아바타'),
              const SizedBox(height: Sp.x3),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: Sp.x3,
                  mainAxisSpacing: Sp.x3,
                ),
                itemCount: _avatars.length,
                itemBuilder: (context, index) {
                  final bool selected = _selectedAvatar == index;
                  return DsPressable(
                    onTap: () => setState(() => _selectedAvatar = index),
                    child: AnimatedContainer(
                      duration: Motion.micro,
                      decoration: BoxDecoration(
                        color: selected ? c.flameTint : c.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? c.flame : c.borderSubtle,
                          width: selected ? Stroke.thick : Stroke.hairline,
                        ),
                      ),
                      child: Center(
                        child: Text(_avatars[index],
                            style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: Sp.x8),
              _SectionLabel('닉네임'),
              const SizedBox(height: Sp.x3),
              TextField(
                controller: _nickname,
                maxLength: _maxNickname,
                style: DsType.body.on(c.textPrimary),
                decoration: _inputDecoration(c, hint: '$_minNickname~$_maxNickname자'),
              ),
              const SizedBox(height: Sp.x6),
              _SectionLabel('친구 초대 코드', optional: true),
              const SizedBox(height: Sp.x1),
              Text(
                '코드를 입력하면 첫 집중 완료 후 두 사람 모두 ${AppConstants.referralBonus} 크레딧을 받습니다',
                style: DsType.caption.on(c.textTertiary),
              ),
              const SizedBox(height: Sp.x3),
              TextField(
                controller: _inviteCode,
                maxLength: _inviteCodeLength,
                textCapitalization: TextCapitalization.characters,
                style: DsType.body
                    .on(c.textPrimary)
                    .copyWith(letterSpacing: 3, fontWeight: FontWeight.w600)
                    .tnum,
                decoration: _inputDecoration(
                  c,
                  hint: '$_inviteCodeLength자리 코드',
                  prefix: Icon(Icons.card_giftcard_rounded,
                      size: 20, color: c.textTertiary),
                ),
              ),
              const SizedBox(height: Sp.x8),
              DsButton(
                label: _isLoading ? '저장 중…' : '완료',
                size: DsButtonSize.hero,
                onPressed: _isLoading ? null : _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(DsColors c,
      {required String hint, Widget? prefix}) {
    OutlineInputBorder border(Color color, [double width = Stroke.hairline]) =>
        OutlineInputBorder(
          borderRadius: R.rSm,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: DsType.body
          .on(c.textTertiary)
          .copyWith(letterSpacing: 0, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: c.surface,
      prefixIcon: prefix,
      counterStyle: DsType.micro.on(c.textTertiary),
      border: border(c.borderDefault),
      enabledBorder: border(c.borderDefault),
      focusedBorder: border(c.flame),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Row(
      children: <Widget>[
        Text(text, style: DsType.label.on(c.textPrimary)),
        if (optional) ...<Widget>[
          const SizedBox(width: Sp.x2),
          Text('선택', style: DsType.micro.on(c.textTertiary)),
        ],
      ],
    );
  }
}
