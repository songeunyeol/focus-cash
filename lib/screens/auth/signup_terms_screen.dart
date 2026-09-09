import 'package:flutter/material.dart';

import '../../config/legal_texts.dart';
import '../../config/routes.dart';
import '../../design/ds.dart';
import '../../widgets/common/ds_button.dart';
import '../../widgets/common/ds_pressable.dart';


/// 약관 동의 — 전체 동의 한 줄 + 항목 네 줄 + 버튼 하나.
class SignupTermsScreen extends StatefulWidget {
  const SignupTermsScreen({super.key});

  @override
  State<SignupTermsScreen> createState() => _SignupTermsScreenState();
}

class _SignupTermsScreenState extends State<SignupTermsScreen> {
  bool _ageAgreed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _marketingAgreed = false;

  bool get _allAgreed =>
      _ageAgreed && _termsAgreed && _privacyAgreed && _marketingAgreed;

  // 약관 제2조·개인정보 처리방침 4항: 만 14세 미만은 법정대리인 동의 없이 가입 불가.
  bool get _canProceed => _ageAgreed && _termsAgreed && _privacyAgreed;

  void _toggleAll() {
    final bool v = !_allAgreed;
    setState(() {
      _ageAgreed = v;
      _termsAgreed = v;
      _privacyAgreed = v;
      _marketingAgreed = v;
    });
  }

  void _proceed() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.signupProfile,
      arguments: {'marketingAgreed': _marketingAgreed},
    );
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('시작하기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x4, Sp.x6, Sp.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '서비스 이용을 위해 약관에 동의해 주세요',
                style: DsType.body.on(c.textSecondary),
              ),
              const SizedBox(height: Sp.x6),
              _AllAgreeRow(value: _allAgreed, onTap: _toggleAll),
              const SizedBox(height: Sp.x3),
              Container(
                decoration: DsSurface.e1(c),
                child: Column(
                  children: <Widget>[
                    _TermsRow(
                      title: '만 14세 이상입니다',
                      required: true,
                      value: _ageAgreed,
                      onChanged: (v) => setState(() => _ageAgreed = v),
                      onView: () => _showTerms(
                        '만 14세 이상 확인',
                        '만 14세 미만은 법정대리인(부모 등)의 동의가 있어야 가입할 수 있습니다.\n'
                            '만 14세 미만임이 확인되면 계정과 개인정보는 즉시 삭제됩니다.\n\n'
                            '자세한 내용은 개인정보 처리방침 4항을 참고해 주세요.',
                      ),
                    ),
                    _TermsRow(
                      title: '서비스 이용약관',
                      required: true,
                      value: _termsAgreed,
                      onChanged: (v) => setState(() => _termsAgreed = v),
                      onView: () => _showTerms('서비스 이용약관', serviceTermsText),
                    ),
                    _TermsRow(
                      title: '개인정보 처리방침',
                      required: true,
                      value: _privacyAgreed,
                      onChanged: (v) => setState(() => _privacyAgreed = v),
                      onView: () => _showTerms('개인정보 처리방침', privacyPolicyText),
                    ),
                    _TermsRow(
                      title: '마케팅 정보 수신 동의',
                      required: false,
                      value: _marketingAgreed,
                      onChanged: (v) => setState(() => _marketingAgreed = v),
                      onView: () => _showTerms('마케팅 정보 수신 동의', marketingTermsText),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              DsButton(
                label: '동의하고 계속하기',
                size: DsButtonSize.hero,
                onPressed: _canProceed ? _proceed : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTerms(String title, String content) {
    final DsColors c = context.ds;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: R.rSheet),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (context, controller) => Column(
          children: <Widget>[
            const SizedBox(height: Sp.x3),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: R.rPill,
                ),
              ),
            ),
            const SizedBox(height: Sp.x4),
            Padding(
              padding: Sp.screenH,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: DsType.heading.on(c.textPrimary)),
              ),
            ),
            const SizedBox(height: Sp.x3),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: Sp.screenH,
                child: Text(content, style: DsType.body.on(c.textSecondary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Sp.x4),
              child: DsButton(
                label: '확인',
                variant: DsButtonVariant.quiet,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllAgreeRow extends StatelessWidget {
  const _AllAgreeRow({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return DsPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.micro,
        padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
        decoration: DsSurface.of(
          c,
          DsElevation.e1,
          tone: value ? c.flameTint : null,
          borderColor: value ? c.flameDim : null,
        ),
        child: Row(
          children: <Widget>[
            _CheckMark(value: value, strong: true),
            const SizedBox(width: Sp.x3),
            Text('전체 동의', style: DsType.bodyStrong.on(c.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.title,
    required this.required,
    required this.value,
    required this.onChanged,
    required this.onView,
    this.isLast = false,
  });

  final String title;
  final bool required;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onView;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: c.borderSubtle, width: Stroke.hairline),
              ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DsPressable(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4, vertical: Sp.x3),
                child: Row(
                  children: <Widget>[
                    _CheckMark(value: value),
                    const SizedBox(width: Sp.x3),
                    Text(
                      required ? '필수' : '선택',
                      style: DsType.micro
                          .on(required ? c.accentText : c.textTertiary),
                    ),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Text(
                        title,
                        style: DsType.body
                            .on(value ? c.textPrimary : c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          DsPressable(
            onTap: onView,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Sp.x4, vertical: Sp.x3),
              child: Text('보기', style: DsType.caption.on(c.textTertiary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.value, this.strong = false});

  final bool value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return AnimatedContainer(
      duration: Motion.micro,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? c.flame : Colors.transparent,
        borderRadius: R.rSm,
        border: Border.all(
          color: value ? c.flame : (strong ? c.borderStrong : c.borderDefault),
          width: Stroke.hairline,
        ),
      ),
      child: value
          ? Icon(Icons.check_rounded, size: 16, color: c.onAccent)
          : null,
    );
  }
}
