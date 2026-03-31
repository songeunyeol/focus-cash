import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSession {
  final String id;
  final String userId;
  final int targetMinutes;
  final int actualMinutes;
  final int creditsEarned;
  final String hardcoreMode; // 'normal', 'hardcore', 'ultra'
  final String tag; // subject tag
  final bool completed;
  final bool watchedStartAd;
  final bool watchedEndAd;
  final DateTime startedAt;
  final DateTime? endedAt;

  const FocusSession({
    required this.id,
    required this.userId,
    required this.targetMinutes,
    this.actualMinutes = 0,
    this.creditsEarned = 0,
    this.hardcoreMode = 'normal',
    this.tag = '',
    this.completed = false,
    this.watchedStartAd = false,
    this.watchedEndAd = false,
    required this.startedAt,
    this.endedAt,
  });

  FocusSession copyWith({
    String? id,
    String? userId,
    int? targetMinutes,
    int? actualMinutes,
    int? creditsEarned,
    String? hardcoreMode,
    String? tag,
    bool? completed,
    bool? watchedStartAd,
    bool? watchedEndAd,
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      creditsEarned: creditsEarned ?? this.creditsEarned,
      hardcoreMode: hardcoreMode ?? this.hardcoreMode,
      tag: tag ?? this.tag,
      completed: completed ?? this.completed,
      watchedStartAd: watchedStartAd ?? this.watchedStartAd,
      watchedEndAd: watchedEndAd ?? this.watchedEndAd,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'targetMinutes': targetMinutes,
      'actualMinutes': actualMinutes,
      'creditsEarned': creditsEarned,
      'hardcoreMode': hardcoreMode,
      'tag': tag,
      'completed': completed,
      'watchedStartAd': watchedStartAd,
      'watchedEndAd': watchedEndAd,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as String,
      userId: map['userId'] as String,
      targetMinutes: map['targetMinutes'] as int,
      actualMinutes: map['actualMinutes'] as int? ?? 0,
      creditsEarned: map['creditsEarned'] as int? ?? 0,
      hardcoreMode: map['hardcoreMode'] as String? ?? 'normal',
      tag: map['tag'] as String? ?? '',
      completed: map['completed'] as bool? ?? false,
      watchedStartAd: map['watchedStartAd'] as bool? ?? false,
      watchedEndAd: map['watchedEndAd'] as bool? ?? false,
      startedAt: _parseDateTime(map['startedAt']),
      endedAt: map['endedAt'] != null ? _parseDateTime(map['endedAt']) : null,
    );
  }
}
