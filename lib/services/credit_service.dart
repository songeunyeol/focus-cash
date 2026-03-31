import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/credit_transaction.dart';

class CreditService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  int calculateSessionCredits({
    required int focusMinutes,
    required bool watchedStartAd,
    required bool watchedEndAd,
    String hardcoreMode = 'normal',
  }) {
    final tenMinBlocks = focusMinutes ~/ 10;
    int baseCredits = tenMinBlocks * AppConstants.creditsPerTenMinutes;

    // 하드코어 완료 시 기본 크레딧 1.2배
    if (hardcoreMode == 'hardcore') {
      baseCredits = (baseCredits * AppConstants.hardcoreBonusRate).round();
    }

    if (watchedStartAd) baseCredits += AppConstants.startAdBonus;
    // 종료 광고 보너스는 focus_provider.addEndAdBonus()에서 별도 처리
    return baseCredits;
  }

  Future<int> addCredits({
    required String userId,
    required int amount,
    required String description,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<int>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('User not found');

      final data = userDoc.data()!;
      final currentTotal = data['totalCredits'] as int? ?? 0;
      final currentToday = data['todayCredits'] as int? ?? 0;

      // 날짜가 바뀌었으면 todayCredits 리셋
      final lastActiveStr = data['lastActiveAt'] as String?;
      final lastActive =
          lastActiveStr != null ? DateTime.tryParse(lastActiveStr) : null;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDay = lastActive != null
          ? DateTime(lastActive.year, lastActive.month, lastActive.day)
          : null;
      final isNewDay =
          lastDay == null || !lastDay.isAtSameMomentAs(today);
      final newTodayCredits =
          isNewDay ? amount : currentToday + amount;

      transaction.update(userRef, {
        'totalCredits': currentTotal + amount,
        'todayCredits': newTodayCredits,
        'lastActiveAt': now.toIso8601String(),
      });

      // Record transaction
      final txRef = _firestore.collection('credit_transactions').doc();
      transaction.set(txRef, CreditTransaction(
        id: _uuid.v4(),
        userId: userId,
        amount: amount,
        type: 'earn',
        description: description,
        createdAt: DateTime.now(),
      ).toMap());

      return amount;
    });
  }

  Future<bool> spendCredits({
    required String userId,
    required int amount,
    required String description,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<bool>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return false;

      final currentTotal = userDoc.data()!['totalCredits'] as int? ?? 0;
      if (currentTotal < amount) return false;

      transaction.update(userRef, {
        'totalCredits': currentTotal - amount,
      });

      final txRef = _firestore.collection('credit_transactions').doc();
      transaction.set(txRef, CreditTransaction(
        id: _uuid.v4(),
        userId: userId,
        amount: -amount,
        type: 'spend',
        description: description,
        createdAt: DateTime.now(),
      ).toMap());

      return true;
    });
  }

  Future<int> applyPenalty({
    required String userId,
    required double penaltyRate,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<int>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return 0;

      final currentTotal = userDoc.data()!['totalCredits'] as int? ?? 0;
      final penalty = (currentTotal * penaltyRate).round();

      transaction.update(userRef, {
        'totalCredits': currentTotal - penalty,
      });

      final txRef = _firestore.collection('credit_transactions').doc();
      transaction.set(txRef, CreditTransaction(
        id: _uuid.v4(),
        userId: userId,
        amount: -penalty,
        type: 'penalty',
        description: '하드코어 모드 페널티',
        createdAt: DateTime.now(),
      ).toMap());

      return penalty;
    });
  }

  Future<List<CreditTransaction>> getTransactionHistory(String userId,
      {int limit = 50}) async {
    final snapshot = await _firestore
        .collection('credit_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => CreditTransaction.fromMap(doc.data()))
        .toList();
  }
}
