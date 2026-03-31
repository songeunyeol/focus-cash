import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/daily_note.dart';

class NoteService {
  NoteService._();
  static final NoteService instance = NoteService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _dateStr(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // 특정 날짜의 메모 가져오기
  Future<DailyNote?> getNote(String userId, DateTime date) async {
    try {
      final docId = '${userId}_${_dateStr(date)}';
      final snap = await _db.collection('user_notes').doc(docId).get();
      if (!snap.exists || snap.data() == null) return null;
      return DailyNote.fromMap(snap.data()!);
    } catch (e) {
      debugPrint('[NoteService] getNote 오류: $e');
      return null;
    }
  }

  // 메모 저장 (없으면 생성, 있으면 업데이트)
  Future<void> saveNote(String userId, DateTime date, String memo) async {
    try {
      final dateStr = _dateStr(date);
      final docId = '${userId}_$dateStr';
      await _db.collection('user_notes').doc(docId).set({
        'userId': userId,
        'date': dateStr,
        'memo': memo,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[NoteService] saveNote 오류: $e');
    }
  }

  // 월별 메모 전체 가져오기 (캘린더용)
  Future<Map<String, DailyNote>> getMonthNotes(String userId, int year, int month) async {
    try {
      final query = await _db
          .collection('user_notes')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: '${year.toString()}-${month.toString().padLeft(2, '0')}-01')
          .where('date', isLessThan: _nextMonthPrefix(year, month))
          .get();

      final result = <String, DailyNote>{};
      for (final doc in query.docs) {
        final note = DailyNote.fromMap(doc.data());
        result[note.date] = note;
      }
      return result;
    } catch (e) {
      debugPrint('[NoteService] getMonthNotes 오류: $e');
      return {};
    }
  }

  String _nextMonthPrefix(int year, int month) {
    if (month == 12) {
      return '${year + 1}-01-01';
    }
    return '$year-${(month + 1).toString().padLeft(2, '0')}-01';
  }
}
