class DailyNote {
  final String userId;
  final String date;   // 'YYYY-MM-DD'
  final String memo;
  final DateTime updatedAt;

  const DailyNote({
    required this.userId,
    required this.date,
    this.memo = '',
    required this.updatedAt,
  });

  String get docId => '${userId}_$date';

  DailyNote copyWith({String? memo, DateTime? updatedAt}) {
    return DailyNote(
      userId: userId,
      date: date,
      memo: memo ?? this.memo,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'date': date,
        'memo': memo,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DailyNote.fromMap(Map<String, dynamic> map) => DailyNote(
        userId: map['userId'] as String,
        date: map['date'] as String,
        memo: map['memo'] as String? ?? '',
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}
