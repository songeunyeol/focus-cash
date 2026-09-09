import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/version_gate.dart';

void main() {
  group('evaluateVersionGate', () {
    const policy = VersionPolicy(minBuildNumber: 4, latestBuildNumber: 6);

    test('최소 빌드 미만이면 강제', () {
      expect(evaluateVersionGate(currentBuild: 3, policy: policy),
          UpdateRequirement.required);
    });

    test('최소 이상·최신 미만이면 권장', () {
      expect(evaluateVersionGate(currentBuild: 4, policy: policy),
          UpdateRequirement.recommended);
      expect(evaluateVersionGate(currentBuild: 5, policy: policy),
          UpdateRequirement.recommended);
    });

    test('최신 이상이면 없음', () {
      expect(evaluateVersionGate(currentBuild: 6, policy: policy),
          UpdateRequirement.none);
      expect(evaluateVersionGate(currentBuild: 99, policy: policy),
          UpdateRequirement.none);
    });

    test('열린 정책은 아무도 막지 않는다', () {
      expect(evaluateVersionGate(currentBuild: 0, policy: VersionPolicy.open),
          UpdateRequirement.none);
    });
  });

  group('VersionPolicy.fromMap', () {
    test('문서가 없으면 open', () {
      expect(VersionPolicy.fromMap(null).minBuildNumber, 0);
      expect(VersionPolicy.fromMap(null).latestBuildNumber, 0);
    });

    test('숫자·문자열·실수 모두 읽고 빠진 필드는 0', () {
      final p = VersionPolicy.fromMap({
        'minBuildNumber': '4',
        'latestBuildNumber': 6.0,
        'storeUrl': 'https://play.google.com/store/apps/details?id=x',
      });
      expect(p.minBuildNumber, 4);
      expect(p.latestBuildNumber, 6);
      expect(p.storeUrl, contains('play.google.com'));
      expect(p.message, '');
    });

    test('타입이 엉망이면 그 필드만 0 (앱이 죽지 않는다)', () {
      final p = VersionPolicy.fromMap({'minBuildNumber': true});
      expect(p.minBuildNumber, 0);
    });
  });
}
