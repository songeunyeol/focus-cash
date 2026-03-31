import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String displayName;
  final int totalCredits;
  final int todayCredits;
  final int totalFocusMinutes;
  final int todayFocusMinutes;
  final int currentStreak;
  final int longestStreak;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int avatarIndex;
  final DateTime? termsAgreedAt;
  final bool marketingAgreed;
  final String rouletteDate;
  final int rouletteSpinsToday;
  final String inviteCode;
  final String invitedBy;
  final bool inviteBonusGiven;

  // ── 레벨/XP/배지 ──────────────────────────
  final int xp;
  final int level;
  final List<String> badges;
  final String lastCheckInDate; // 'YYYY-MM-DD'
  final int hardcoreSessionCount; // 하드코어 완료 횟수
  final int inviteCount;          // 초대 성공 횟수

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.displayName = '',
    this.totalCredits = 0,
    this.todayCredits = 0,
    this.totalFocusMinutes = 0,
    this.todayFocusMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.isPremium = false,
    required this.createdAt,
    required this.lastActiveAt,
    this.avatarIndex = 0,
    this.termsAgreedAt,
    this.marketingAgreed = false,
    this.rouletteDate = '',
    this.rouletteSpinsToday = 0,
    this.inviteCode = '',
    this.invitedBy = '',
    this.inviteBonusGiven = false,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.lastCheckInDate = '',
    this.hardcoreSessionCount = 0,
    this.inviteCount = 0,
  });

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    int? totalCredits,
    int? todayCredits,
    int? totalFocusMinutes,
    int? todayFocusMinutes,
    int? currentStreak,
    int? longestStreak,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? avatarIndex,
    DateTime? termsAgreedAt,
    bool? marketingAgreed,
    String? rouletteDate,
    int? rouletteSpinsToday,
    String? inviteCode,
    String? invitedBy,
    bool? inviteBonusGiven,
    int? xp,
    int? level,
    List<String>? badges,
    String? lastCheckInDate,
    int? hardcoreSessionCount,
    int? inviteCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      totalCredits: totalCredits ?? this.totalCredits,
      todayCredits: todayCredits ?? this.todayCredits,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      todayFocusMinutes: todayFocusMinutes ?? this.todayFocusMinutes,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      termsAgreedAt: termsAgreedAt ?? this.termsAgreedAt,
      marketingAgreed: marketingAgreed ?? this.marketingAgreed,
      rouletteDate: rouletteDate ?? this.rouletteDate,
      rouletteSpinsToday: rouletteSpinsToday ?? this.rouletteSpinsToday,
      inviteCode: inviteCode ?? this.inviteCode,
      invitedBy: invitedBy ?? this.invitedBy,
      inviteBonusGiven: inviteBonusGiven ?? this.inviteBonusGiven,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      hardcoreSessionCount: hardcoreSessionCount ?? this.hardcoreSessionCount,
      inviteCount: inviteCount ?? this.inviteCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'totalCredits': totalCredits,
      'todayCredits': todayCredits,
      'totalFocusMinutes': totalFocusMinutes,
      'todayFocusMinutes': todayFocusMinutes,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'isPremium': isPremium,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'avatarIndex': avatarIndex,
      'termsAgreedAt': termsAgreedAt?.toIso8601String(),
      'marketingAgreed': marketingAgreed,
      'rouletteDate': rouletteDate,
      'rouletteSpinsToday': rouletteSpinsToday,
      'inviteCode': inviteCode,
      'invitedBy': invitedBy,
      'inviteBonusGiven': inviteBonusGiven,
      'xp': xp,
      'level': level,
      'badges': badges,
      'lastCheckInDate': lastCheckInDate,
      'hardcoreSessionCount': hardcoreSessionCount,
      'inviteCount': inviteCount,
    };
  }

  static DateTime _parseDateTime(dynamic value, DateTime fallback) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return UserModel(
      uid: map['uid'] as String,
      phoneNumber: map['phoneNumber'] as String,
      displayName: map['displayName'] as String? ?? '',
      totalCredits: map['totalCredits'] as int? ?? 0,
      todayCredits: map['todayCredits'] as int? ?? 0,
      totalFocusMinutes: map['totalFocusMinutes'] as int? ?? 0,
      todayFocusMinutes: map['todayFocusMinutes'] as int? ?? 0,
      currentStreak: map['currentStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      isPremium: map['isPremium'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt'], now),
      lastActiveAt: _parseDateTime(map['lastActiveAt'], now),
      avatarIndex: map['avatarIndex'] as int? ?? 0,
      termsAgreedAt: map['termsAgreedAt'] != null
          ? _parseDateTime(map['termsAgreedAt'], now)
          : null,
      marketingAgreed: map['marketingAgreed'] as bool? ?? false,
      rouletteDate: map['rouletteDate'] as String? ?? '',
      rouletteSpinsToday: map['rouletteSpinsToday'] as int? ?? 0,
      inviteCode: map['inviteCode'] as String? ?? '',
      invitedBy: map['invitedBy'] as String? ?? '',
      inviteBonusGiven: map['inviteBonusGiven'] as bool? ?? false,
      xp: map['xp'] as int? ?? 0,
      level: map['level'] as int? ?? 1,
      badges: (map['badges'] as List<dynamic>?)?.cast<String>() ?? [],
      lastCheckInDate: map['lastCheckInDate'] as String? ?? '',
      hardcoreSessionCount: map['hardcoreSessionCount'] as int? ?? 0,
      inviteCount: map['inviteCount'] as int? ?? 0,
    );
  }
}
