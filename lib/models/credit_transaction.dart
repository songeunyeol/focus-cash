import 'package:cloud_firestore/cloud_firestore.dart';

class CreditTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type; // 'earn', 'spend', 'penalty', 'refund'
  final String description;
  final DateTime createdAt;

  /// 'server' 면 Cloud Functions 가 쓴 원장. 없으면(구버전) 클라이언트가 썼다.
  final String source;

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
    this.source = 'client',
  });

  bool get isFromServer => source == 'server';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
    };
  }

  /// 서버 원장은 `createdAt`(문자열, 정렬 호환) 과 `createdAtTs`(Timestamp) 를 둘 다 쓴다.
  /// 어느 쪽이 와도 읽는다. 형식이 깨진 옛 데이터는 epoch 로 두고 목록에서 죽지 않게 한다.
  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? 'earn',
      description: map['description'] as String? ?? '',
      createdAt: _parseDate(map['createdAtTs'] ?? map['createdAt']),
      source: map['source'] as String? ?? 'client',
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
