/// 앱 버전 게이트 — 규칙 v2 배포 뒤 구버전 앱 대응.
///
/// Firestore 규칙이 v2 로 바뀌면 클라이언트가 직접 잔액을 쓰던 구버전 앱은
/// 정산·교환이 전부 permission-denied 로 실패한다. 서버가 `app_config/android` 문서에
/// 최소 빌드 번호를 올려두면, 앱은 시작 시 이 판정으로 업데이트 화면을 띄운다.
///
/// 서버 `functions/src/rules.ts` 의 `evaluateVersionGate` 와 같은 규칙이다.
enum UpdateRequirement { none, recommended, required }

/// 원격 설정 문서(`app_config/android`)의 값. 문서가 없으면 [VersionPolicy.open].
class VersionPolicy {
  const VersionPolicy({
    required this.minBuildNumber,
    required this.latestBuildNumber,
    this.storeUrl = '',
    this.message = '',
  });

  /// 이 빌드 미만은 실행 불가 (강제 업데이트)
  final int minBuildNumber;

  /// 이 빌드 미만은 권장 업데이트 안내
  final int latestBuildNumber;

  /// 업데이트 버튼이 여는 주소 (Play 스토어). 비어 있으면 기본 Play 링크.
  final String storeUrl;

  /// 운영자가 쓰는 안내 문구 (선택)
  final String message;

  /// 문서가 없거나 깨졌을 때 — 아무도 막지 않는다.
  static const VersionPolicy open =
      VersionPolicy(minBuildNumber: 0, latestBuildNumber: 0);

  /// Firestore 문서 → 정책. 필드가 빠졌거나 타입이 다르면 그 필드만 0/빈값 처리.
  factory VersionPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null) return open;
    int readInt(String key) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return VersionPolicy(
      minBuildNumber: readInt('minBuildNumber'),
      latestBuildNumber: readInt('latestBuildNumber'),
      storeUrl: map['storeUrl'] as String? ?? '',
      message: map['message'] as String? ?? '',
    );
  }
}

/// 현재 빌드 번호와 정책을 비교한다. 순수 함수.
UpdateRequirement evaluateVersionGate({
  required int currentBuild,
  required VersionPolicy policy,
}) {
  if (currentBuild < policy.minBuildNumber) return UpdateRequirement.required;
  if (currentBuild < policy.latestBuildNumber) {
    return UpdateRequirement.recommended;
  }
  return UpdateRequirement.none;
}
