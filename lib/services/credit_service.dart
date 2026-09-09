import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../config/constants.dart';
import '../domain/credit_rules.dart';
import '../domain/streak_rules.dart';
import '../models/credit_transaction.dart';

/// 크레딧 원장 접근.
///
/// **쓰기 메서드([addCredits]·[spendCredits]·[applyPenalty])는 서버 이관 전용 과도기 코드다.**
/// 서버 스위치(`AppConfig.useServerSettlement` + `useServerStore`)가 모두 켜지면 호출처가 없어야 하고,
/// 그 상태에서 호출되면 [StateError] 로 즉시 드러낸다. 규칙 v2 가 배포되면 Firestore 가
/// permission-denied 로 막지만, 배포 전에 코드 경로에서 잡는 것이 목적이다.
/// 이관이 끝나면 이 세 메서드와 [_assertClientWritesAllowed] 를 지운다 (docs/SERVER_MIGRATION.md 5단계).
class CreditService {
  /// 테스트에서 가짜 인스턴스를 주입할 수 있게 지연 초기화한다.
  /// (`FirebaseFirestore.instance` 를 필드 초기화에서 바로 잡으면 Firebase 미초기화 환경에서 생성 자체가 실패한다)
  CreditService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  late final FirebaseFirestore _firestore = _injected ?? FirebaseFirestore.instance;
  final _uuid = const Uuid();

  int calculateSessionCredits({
    required int focusMinutes,
    required bool watchedStartAd,
    required bool watchedEndAd,
    String hardcoreMode = 'normal',
  }) =>
      CreditRules.sessionCredits(
        focusMinutes: focusMinutes,
        hardcoreMode: hardcoreMode,
        watchedStartAd: watchedStartAd,
      );

  static void _assertClientWritesAllowed(String method) {
    if (!AppConfig.clientBalanceWritesAllowed) {
      throw StateError(
        'CreditService.$method: 서버 이관 모드에서는 클라이언트가 잔액을 쓸 수 없습니다. '
        'ServerApi 를 사용하세요.',
      );
    }
  }

  /// 크레딧 지급. 실제 지급된 양을 돌려준다. (과도기 — 서버 모드에서는 호출 금지)
  ///
  /// [dailyCap] 을 주면 오늘 적립량(`todayCredits`)과 합쳐 한도를 넘는 부분은 잘라낸다.
  /// 집중·광고 보너스처럼 약관상 일일 한도(250)에 묶이는 지급에만 넘기고,
  /// 룰렛 당첨·환불·초대 보너스는 넘기지 않는다.
  Future<int> addCredits({
    required String userId,
    required int amount,
    required String description,
    int? dailyCap,
  }) async {
    _assertClientWritesAllowed('addCredits');
    if (amount <= 0) return 0;
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<int>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) throw Exception('User not found');

      final data = userDoc.data()!;
      final currentTotal = data['totalCredits'] as int? ?? 0;
      final currentToday = data['todayCredits'] as int? ?? 0;

      // 날짜가 바뀌었으면 todayCredits 리셋.
      // 기준은 마지막 적립일(creditDate)이다. lastActiveAt 은 다른 이벤트에도 갱신돼 신뢰할 수 없다.
      final now = DateTime.now();
      final creditDateStr = data['creditDate'] as String? ?? '';
      final creditDate = DateTime.tryParse(creditDateStr);
      final isNewDay = creditDate == null || !isSameDay(creditDate, now);
      final todayBefore = isNewDay ? 0 : currentToday;

      final granted = CreditRules.applyDailyCap(
        todayCredits: todayBefore,
        amount: amount,
        cap: dailyCap,
      );
      if (granted <= 0) return 0;

      transaction.update(userRef, {
        'totalCredits': currentTotal + granted,
        'todayCredits': todayBefore + granted,
        'creditDate': _dateKey(now),
        'lastActiveAt': now.toIso8601String(),
      });

      final txRef = _firestore.collection('credit_transactions').doc();
      transaction.set(
          txRef,
          CreditTransaction(
            id: _uuid.v4(),
            userId: userId,
            amount: granted,
            type: 'earn',
            description: granted < amount
                ? '$description (일일 한도 적용)'
                : description,
            createdAt: now,
          ).toMap());

      return granted;
    });
  }

  /// 크레딧 차감. 잔액 부족이면 false. (과도기 — 서버 모드에서는 호출 금지)
  Future<bool> spendCredits({
    required String userId,
    required int amount,
    required String description,
  }) async {
    _assertClientWritesAllowed('spendCredits');
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
      transaction.set(
          txRef,
          CreditTransaction(
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

  /// 하드코어 포기 페널티. (과도기 — 서버 모드에서는 abandonSession 이 처리)
  Future<int> applyPenalty({
    required String userId,
    required double penaltyRate,
  }) async {
    _assertClientWritesAllowed('applyPenalty');
    final userRef = _firestore.collection('users').doc(userId);

    return _firestore.runTransaction<int>((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return 0;

      final currentTotal = userDoc.data()!['totalCredits'] as int? ?? 0;
      final penalty = (currentTotal * penaltyRate).round();
      if (penalty <= 0) return 0;

      transaction.update(userRef, {
        'totalCredits': currentTotal - penalty,
      });

      final txRef = _firestore.collection('credit_transactions').doc();
      transaction.set(
          txRef,
          CreditTransaction(
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

  /// 원장 조회. 서버·클라이언트 어느 쪽이 쓴 항목이든 같은 컬렉션이다.
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

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 약관 제4조 ② "일일 최대 적립 크레딧" 과 코드가 같은 숫자를 보게 하는 상수 접근자.
int get kDailyCreditCap => AppConstants.dailyCreditCap;
