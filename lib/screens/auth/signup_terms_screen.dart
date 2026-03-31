import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';

class SignupTermsScreen extends StatefulWidget {
  const SignupTermsScreen({super.key});

  @override
  State<SignupTermsScreen> createState() => _SignupTermsScreenState();
}

class _SignupTermsScreenState extends State<SignupTermsScreen> {
  bool _allAgreed = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _marketingAgreed = false;

  void _toggleAll(bool? value) {
    final v = value ?? false;
    setState(() {
      _allAgreed = v;
      _termsAgreed = v;
      _privacyAgreed = v;
      _marketingAgreed = v;
    });
  }

  void _updateAll() {
    setState(() {
      _allAgreed = _termsAgreed && _privacyAgreed && _marketingAgreed;
    });
  }

  bool get _canProceed => _termsAgreed && _privacyAgreed;

  void _proceed() {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.signupProfile,
      arguments: {'marketingAgreed': _marketingAgreed},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // 상단 아이콘 — 그라디언트 컨테이너
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.description_outlined,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 타이틀 — ShaderMask 그라디언트
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  'Focus Cash 시작하기',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                '서비스 이용을 위해 약관에 동의해주세요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.of(context).textSecondary,
                    ),
              ),

              SizedBox(height: 36),

              // 전체 동의 카드
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _allAgreed
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : AppTheme.of(context).borderMid,
                    width: 1,
                  ),
                  boxShadow: _allAgreed
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 0,
                          )
                        ]
                      : null,
                ),
                child: CheckboxListTile(
                  value: _allAgreed,
                  onChanged: _toggleAll,
                  title: Text(
                    '전체 동의',
                    style: TextStyle(
                      color: AppTheme.of(context).textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              SizedBox(height: 8),
              Divider(
                color: AppTheme.of(context).borderSubtle,
                height: 16,
              ),

              // 이용약관 (필수)
              _TermsItem(
                title: '[필수] 서비스 이용약관',
                value: _termsAgreed,
                onChanged: (v) {
                  setState(() => _termsAgreed = v ?? false);
                  _updateAll();
                },
                onTap: () => _showTermsDialog(context, '서비스 이용약관', serviceTermsText),
              ),

              // 개인정보 처리방침 (필수)
              _TermsItem(
                title: '[필수] 개인정보 처리방침',
                value: _privacyAgreed,
                onChanged: (v) {
                  setState(() => _privacyAgreed = v ?? false);
                  _updateAll();
                },
                onTap: () => _showTermsDialog(context, '개인정보 처리방침', privacyPolicyText),
              ),

              // 마케팅 수신 동의 (선택)
              _TermsItem(
                title: '[선택] 마케팅 정보 수신 동의',
                value: _marketingAgreed,
                onChanged: (v) {
                  setState(() => _marketingAgreed = v ?? false);
                  _updateAll();
                },
                onTap: () => _showTermsDialog(context, '마케팅 정보 수신 동의', marketingTermsText),
              ),

              const Spacer(),

              // 다음 버튼 — glowButton
              _canProceed
                  ? Container(
                      height: 54,
                      decoration: AppTheme.glowButton,
                      child: ElevatedButton(
                        onPressed: _proceed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '동의하고 계속하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.of(context).surface,
                          disabledBackgroundColor: AppTheme.of(context).surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '동의하고 계속하기',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsDialog(BuildContext context, String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.of(context).textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  content,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermsItem extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTap;

  const _TermsItem({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryColor,
        ),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: value ? AppTheme.of(context).textPrimary : AppTheme.of(context).textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text(
            '보기',
            style: TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────
// 약관 내용
// ───────────────────────────────────────────

// 외부에서도 접근 가능하도록 public으로 선언
const serviceTermsText = '''
제1조 (목적)
본 약관은 송은열(이하 "운영자")이 제공하는 Focus Cash 애플리케이션(이하 "서비스")의 이용 조건 및 절차, 이용자와 운영자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.

운영자 정보
- 운영자: 송은열
- 문의 이메일: songeunyeol@naver.com

제2조 (이용 자격)
① 본 서비스는 만 14세 이상인 자가 이용할 수 있습니다.
② 만 14세 미만의 경우 법정대리인(부모 등)의 동의를 받아야 하며, 동의 없이 가입한 경우 운영자는 해당 계정을 삭제할 수 있습니다.
③ 이용자는 본 약관에 동의함으로써 서비스를 이용할 수 있습니다.

제3조 (서비스 내용)
① 서비스는 집중 타이머를 통해 크레딧을 적립하고, 이를 상품으로 교환하는 기능을 제공합니다.
② 크레딧은 현금으로 환급되지 않으며, 서비스 내 상품 교환에만 사용할 수 있습니다.
③ 광고 시청을 통해 추가 크레딧을 획득할 수 있습니다.

제4조 (크레딧 정책)
① 크레딧은 집중 세션 완료 시 분당 1크레딧으로 적립됩니다.
② 일일 최대 적립 크레딧은 250 크레딧으로 제한됩니다.
③ 어뷰징(비정상적 이용)이 의심되는 경우 크레딧 적립이 제한되거나 적립된 크레딧이 회수될 수 있습니다.
④ 운영자는 크레딧 정책을 7일 전 사전 고지 후 변경할 수 있습니다.
⑤ 계정 탈퇴 시 잔여 크레딧은 소멸되며 복구되지 않습니다.

제5조 (상품 교환 및 환불 정책)
① 크레딧으로 교환한 상품(기프티콘 등)은 교환 완료 후 취소 및 환불이 불가합니다.
② 단, 운영자의 귀책사유로 상품이 정상 지급되지 않은 경우 재지급 또는 크레딧 복구 조치를 취합니다.
③ 상품 교환 관련 문의는 songeunyeol@naver.com으로 연락해 주시기 바랍니다.

제6조 (계정 관리 및 탈퇴)
① 이용자는 앱 내 [프로필 > 설정 > 계정 탈퇴] 메뉴를 통해 언제든지 탈퇴할 수 있습니다.
② 탈퇴 시 모든 데이터(크레딧, 집중 기록 등)는 30일 이내 파기됩니다.
③ 탈퇴 후 동일 계정으로 재가입 시 이전 데이터는 복구되지 않습니다.

제7조 (이용자의 의무)
① 이용자는 타인의 계정을 이용하거나 허위 정보를 제공하지 않아야 합니다.
② 자동화 프로그램, 매크로 등을 이용한 비정상적 크레딧 적립을 금지합니다.
③ 서비스 시스템을 해킹하거나 방해하는 행위를 금지합니다.
④ 위반 시 사전 통보 없이 서비스 이용이 제한될 수 있습니다.

제8조 (서비스 변경 및 중단)
① 운영자는 서비스 내용을 변경하거나 일시 중단할 수 있으며, 중요한 변경 시 앱 내 공지 또는 이메일로 사전 안내합니다.
② 불가항력적 사유(천재지변, 시스템 장애 등)로 인한 서비스 중단에 대해서는 책임을 지지 않습니다.

제9조 (분쟁 해결)
① 본 약관은 대한민국 법률에 따라 해석됩니다.
② 서비스 이용과 관련한 분쟁은 운영자와 이용자 간 협의를 통해 해결하며, 협의가 이루어지지 않을 경우 서울중앙지방법원을 관할 법원으로 합니다.

시행일: 2026년 3월 11일
''';

const privacyPolicyText = '''
Focus Cash 개인정보 처리방침

송은열(이하 "운영자")은 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수합니다.

1. 개인정보 수집 항목 및 수집 방법

[필수 항목]
- 소셜 로그인 정보: 이름, 이메일 주소
- 서비스 이용 기록: 집중 세션 기록, 크레딧 적립/사용 내역
- 기기 정보: 기기 식별자(UID), OS 버전, 앱 버전

[선택 항목]
- 마케팅 수신 동의 여부

수집 방법: 소셜 로그인(Google, 카카오) 및 서비스 이용 과정에서 자동 수집

2. 개인정보 수집 및 이용 목적
- 회원 가입 및 본인 확인
- 크레딧 적립 및 상품 교환 서비스 제공
- 랭킹, 통계 등 서비스 기능 제공
- 서비스 개선 및 신규 기능 개발
- 마케팅 및 이벤트 안내 (동의한 경우에 한함)

3. 개인정보 보유 및 이용 기간
- 원칙: 회원 탈퇴 후 30일 이내 파기
- 예외 (관련 법령에 따라 보관):
  · 계약 또는 청약철회 기록: 5년 (전자상거래법)
  · 소비자 불만 또는 분쟁 처리 기록: 3년 (전자상거래법)
  · 접속 로그 기록: 3개월 (통신비밀보호법)

4. 만 14세 미만 아동의 개인정보
만 14세 미만 아동의 개인정보는 법정대리인의 동의 없이 수집하지 않습니다.
만 14세 미만임이 확인될 경우 해당 계정 및 개인정보를 즉시 파기합니다.

5. 개인정보 제3자 제공
운영자는 이용자의 동의 없이 개인정보를 제3자에게 제공하지 않습니다.
단, 다음의 경우는 예외입니다:
- 법령에 의거하거나 수사기관의 요청이 있는 경우
- 이용자의 사전 동의가 있는 경우

6. 개인정보 처리 위탁

수탁업체 / 위탁 업무
- Google Firebase: 서버 운영, 회원 인증, 데이터 저장
- Google AdMob: 광고 서비스 제공
- 카카오: 소셜 로그인 인증

7. 개인정보 보호 책임자
- 성명: 송은열
- 이메일: songeunyeol@naver.com
- 문의 가능 시간: 평일 10:00 ~ 18:00

8. 이용자의 권리
이용자는 언제든지 다음 권리를 행사할 수 있습니다:
- 개인정보 열람 요청
- 개인정보 수정 요청
- 개인정보 삭제 요청 (계정 탈퇴)
- 개인정보 처리 정지 요청

요청 방법: songeunyeol@naver.com으로 이메일 문의
처리 기간: 요청 접수 후 10일 이내 처리

9. 개인정보의 파기 절차 및 방법
- 전자적 파일: 복구 불가능한 방법으로 영구 삭제
- 종이 문서: 분쇄 또는 소각

시행일: 2026년 3월 11일
''';

const marketingTermsText = '''
마케팅 정보 수신 동의 (선택)

Focus Cash는 더 나은 서비스 이용을 위해 아래와 같은 마케팅 정보를 발송할 수 있습니다.

발송 내용
- 신규 상품 및 이벤트 안내
- 크레딧 혜택 및 한정 프로모션 알림
- 서비스 업데이트 및 새로운 기능 소식
- 집중 챌린지 및 랭킹 이벤트 안내

발송 채널
- 앱 푸시 알림

수신 거부 안내
- 수신 동의 거부 시에도 서비스 이용에는 아무런 제한이 없습니다.
- 동의 후에도 앱 내 [프로필 > 설정 > 알림 설정]에서 언제든지 수신을 거부할 수 있습니다.
- 수신 거부 처리는 요청 후 3영업일 이내에 완료됩니다.

개인정보 보호책임자: 송은열 (songeunyeol@naver.com)
''';
