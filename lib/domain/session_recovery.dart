import 'dart:convert';

/// 앱이 강제 종료된 뒤 다시 켜졌을 때, 남아 있던 세션을 어떻게 할지.
enum RecoveryAction { resume, complete, discard }

/// 목표 종료 시각에서 이 시간이 지나면 완료 처리하지 않고 폐기한다.
const Duration kRecoveryWindow = Duration(hours: 24);

RecoveryAction decideRecovery({
  required DateTime startedAt,
  required int targetMinutes,
  required DateTime now,
}) {
  if (now.isBefore(startedAt)) return RecoveryAction.discard;

  final DateTime targetEnd = startedAt.add(Duration(minutes: targetMinutes));
  if (now.isBefore(targetEnd)) return RecoveryAction.resume;

  if (now.difference(targetEnd) <= kRecoveryWindow) {
    return RecoveryAction.complete;
  }
  return RecoveryAction.discard;
}

/// 로컬에 저장하는 진행 중 세션의 최소 정보.
/// FocusProvider 는 메모리에만 상태를 두므로, 프로세스가 죽으면 이것만 남는다.
class PersistedSession {
  const PersistedSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.targetMinutes,
    required this.hardcoreMode,
    required this.tag,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final int targetMinutes;
  final String hardcoreMode;
  final String tag;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'targetMinutes': targetMinutes,
        'hardcoreMode': hardcoreMode,
        'tag': tag,
      };

  factory PersistedSession.fromJson(Map<String, dynamic> json) =>
      PersistedSession(
        id: json['id'] as String,
        userId: json['userId'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        targetMinutes: json['targetMinutes'] as int,
        hardcoreMode: json['hardcoreMode'] as String? ?? 'normal',
        tag: json['tag'] as String? ?? '',
      );

  String encode() => jsonEncode(toJson());

  /// 깨진 문자열이면 null. 저장소 오류로 앱이 죽는 일은 없어야 한다.
  static PersistedSession? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PersistedSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
