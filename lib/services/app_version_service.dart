import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import '../domain/version_gate.dart';

/// 앱 시작 시 최소 지원 버전을 확인한다.
///
/// 정책 문서: `app_config/android` (규칙: 누구나 읽기, 관리자만 쓰기)
/// ```
/// { minBuildNumber: 4, latestBuildNumber: 5, storeUrl?: "...", message?: "..." }
/// ```
/// 문서가 없거나, 네트워크가 느리거나, 어떤 이유로든 실패하면 **막지 않는다**.
/// 이 검사는 규칙 v2 배포 뒤 구버전 앱이 정산 실패로 헤매는 것을 막는 안내이지,
/// 오프라인 사용자를 잠그는 장치가 아니다.
class AppVersionService {
  AppVersionService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  late final FirebaseFirestore _db = _injected ?? FirebaseFirestore.instance;

  static const String _collection = 'app_config';
  static const String _doc = 'android';
  static const Duration _timeout = Duration(seconds: 3);

  /// 판정 결과와 정책을 함께 돌려준다 (화면이 storeUrl·message 를 쓴다).
  Future<VersionCheck> check() async {
    if (!AppConfig.checkMinimumVersion) return VersionCheck.none;
    try {
      final results = await Future.wait<Object>([
        PackageInfo.fromPlatform(),
        _db.collection(_collection).doc(_doc).get().timeout(_timeout),
      ]);
      final info = results[0] as PackageInfo;
      final snap = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final policy = VersionPolicy.fromMap(snap.data());
      final requirement =
          evaluateVersionGate(currentBuild: currentBuild, policy: policy);
      return VersionCheck(
        requirement: requirement,
        policy: policy,
        currentBuild: currentBuild,
      );
    } catch (e) {
      debugPrint('버전 확인 실패 (무시): $e');
      return VersionCheck.none;
    }
  }
}

class VersionCheck {
  const VersionCheck({
    required this.requirement,
    required this.policy,
    required this.currentBuild,
  });

  final UpdateRequirement requirement;
  final VersionPolicy policy;
  final int currentBuild;

  static const VersionCheck none = VersionCheck(
    requirement: UpdateRequirement.none,
    policy: VersionPolicy.open,
    currentBuild: 0,
  );

  bool get isRequired => requirement == UpdateRequirement.required;

  String get storeUrl =>
      policy.storeUrl.isNotEmpty ? policy.storeUrl : AppConfig.defaultStoreUrl;
}
