import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/session_recovery.dart';

void main() {
  final started = DateTime(2026, 9, 9, 10, 0);

  group('decideRecovery', () {
    test('목표 시간 안이면 이어하기', () {
      expect(
        decideRecovery(
          startedAt: started,
          targetMinutes: 60,
          now: started.add(const Duration(minutes: 20)),
        ),
        RecoveryAction.resume,
      );
    });

    test('목표 시간을 넘겼고 24시간 안이면 완료 처리', () {
      expect(
        decideRecovery(
          startedAt: started,
          targetMinutes: 60,
          now: started.add(const Duration(minutes: 61)),
        ),
        RecoveryAction.complete,
      );
      expect(
        decideRecovery(
          startedAt: started,
          targetMinutes: 60,
          now: started.add(const Duration(hours: 24, minutes: 59)),
        ),
        RecoveryAction.complete,
      );
    });

    test('목표 종료 후 24시간이 지났으면 폐기', () {
      expect(
        decideRecovery(
          startedAt: started,
          targetMinutes: 60,
          now: started.add(const Duration(hours: 25, minutes: 1)),
        ),
        RecoveryAction.discard,
      );
    });

    test('시작 시각이 미래면 (시각 조작) 폐기', () {
      expect(
        decideRecovery(
          startedAt: started,
          targetMinutes: 60,
          now: started.subtract(const Duration(minutes: 1)),
        ),
        RecoveryAction.discard,
      );
    });
  });

  group('PersistedSession', () {
    test('json 라운드트립', () {
      final s = PersistedSession(
        id: 'abc',
        userId: 'u1',
        startedAt: started,
        targetMinutes: 60,
        hardcoreMode: 'hardcore',
        tag: '수학',
      );
      final back = PersistedSession.fromJson(s.toJson());
      expect(back.id, 'abc');
      expect(back.userId, 'u1');
      expect(back.startedAt, started);
      expect(back.targetMinutes, 60);
      expect(back.hardcoreMode, 'hardcore');
      expect(back.tag, '수학');
    });

    test('깨진 json 은 null', () {
      expect(PersistedSession.tryParse('not json'), isNull);
      expect(PersistedSession.tryParse('{"id":1}'), isNull);
    });
  });
}
