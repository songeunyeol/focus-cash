class CreditTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type; // 'earn', 'spend', 'penalty'
  final String description;
  final DateTime createdAt;

  const CreditTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'type': type,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CreditTransaction.fromMap(Map<String, dynamic> map) {
    return CreditTransaction(
      id: map['id'] as String,
      userId: map['userId'] as String,
      amount: map['amount'] as int,
      type: map['type'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
