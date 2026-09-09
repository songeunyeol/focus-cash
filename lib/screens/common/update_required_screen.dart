import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/ds.dart';
import '../../services/app_version_service.dart';
import '../../widgets/common/ds_button.dart';

/// 강제 업데이트 화면.
///
/// 규칙 v2 가 배포된 뒤 구버전 앱은 정산·교환이 전부 실패한다. 실패한 뒤 "오류"라고
/// 보여주는 것보다, 시작 시점에 이유를 말하고 스토어로 보내는 편이 낫다.
/// 뒤로가기로 빠져나갈 수 없다 — 빠져나가도 동작하는 게 없다.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key, required this.check});

  final VersionCheck check;

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.tryParse(check.storeUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스토어를 열 수 없습니다. Play 스토어에서 Focus Cash 를 검색해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final message = check.policy.message.isNotEmpty
        ? check.policy.message
        : '크레딧 정산 방식이 바뀌어 이 버전에서는 집중 기록과 교환이 처리되지 않습니다.\n'
            '최신 버전으로 업데이트하면 기존 크레딧과 기록은 그대로 이어집니다.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: ds.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x6),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: ds.flameTint,
                    borderRadius: R.rMd,
                  ),
                  child: Icon(Icons.system_update_rounded,
                      size: 36, color: ds.flame),
                ),
                const SizedBox(height: Sp.x6),
                Text(
                  '업데이트가 필요합니다',
                  style: DsType.title.copyWith(color: ds.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Sp.x3),
                Text(
                  message,
                  style: DsType.body.copyWith(color: ds.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Sp.x4),
                Text(
                  '현재 빌드 ${check.currentBuild} · 최소 ${check.policy.minBuildNumber}',
                  style: DsType.caption.copyWith(color: ds.textTertiary),
                ),
                const Spacer(flex: 3),
                DsButton(
                  label: '스토어에서 업데이트',
                  icon: Icons.open_in_new_rounded,
                  size: DsButtonSize.hero,
                  onPressed: () => _openStore(context),
                ),
                const SizedBox(height: Sp.x8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
