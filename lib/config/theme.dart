import 'package:flutter/material.dart';

// ── Context 기반 동적 색상 ────────────────────────────────
class _AppColors {
  final bool isDark;
  const _AppColors(this.isDark);

  Color get bg       => isDark ? const Color(0xFF0C0C14) : const Color(0xFFF0F2FF);
  Color get surface  => isDark ? const Color(0xFF14141E) : Colors.white;
  Color get card     => isDark ? const Color(0xFF14141E) : Colors.white;
  Color get elevated => isDark ? const Color(0xFF1C1C28) : const Color(0xFFF5F5FF);
  Color get overlay  => isDark ? const Color(0xFF23232F) : const Color(0xFFEEEEFF);
  Color get borderSubtle => isDark ? const Color(0x0FFFFFFF) : const Color(0x0F000000);
  Color get borderMid    => isDark ? const Color(0x1AFFFFFF) : const Color(0x1A000000);
  Color get textPrimary   => isDark ? const Color(0xFFEAEAEA) : const Color(0xFF1A1A2E);
  Color get textSecondary => isDark ? const Color(0xFF9A9AB0) : const Color(0xFF5A5A6E);
  Color get textMuted     => isDark ? const Color(0xFF5A5A72) : const Color(0xFF9A9AB0);
  Color get storeBg   => isDark ? const Color(0xFF08080F) : const Color(0xFFEEEEFF);
  Color get storeCard => isDark ? const Color(0xFF111120) : Colors.white;
}

class AppTheme {
  AppTheme._();

  // ── 배경 계층 ──────────────────────────────────────
  static const Color backgroundColor = Color(0xFF0C0C14);
  static const Color surfaceColor    = Color(0xFF14141E);
  static const Color cardColor       = Color(0xFF14141E);
  static const Color elevatedColor   = Color(0xFF1C1C28);
  static const Color overlayColor    = Color(0xFF23232F);

  // ── 테두리 ─────────────────────────────────────────
  static const Color borderSubtle = Color(0x0FFFFFFF);
  static const Color borderMid    = Color(0x1AFFFFFF);

  // ── 브랜드 컬러 (인디고 메인 + 시안 포인트) ────────
  static const Color primaryColor   = Color(0xFF4F46E5); // 인디고 메인
  static const Color secondaryColor = Color(0xFF06B6D4); // 시안 포인트
  static const Color accentGold     = Color(0xFFF59E0B); // 크레딧 골드
  static const Color creditGold     = Color(0xFFF59E0B);

  // ── 상태 컬러 ──────────────────────────────────────
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentRed   = Color(0xFFEF4444);

  // ── 텍스트 ─────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFEAEAEA);
  static const Color textSecondary = Color(0xFF9A9AB0);
  static const Color textMuted     = Color(0xFF5A5A72);

  // ── 상점 전용 (게임 아이템샵) ──────────────────────
  static const Color storeBg         = Color(0xFF08080F);
  static const Color storeCard       = Color(0xFF111120);
  static const Color rarityCommon    = Color(0xFF6B7280);
  static const Color rarityRare      = Color(0xFF06B6D4); // 시안
  static const Color rarityEpic      = Color(0xFF4F46E5); // 인디고
  static const Color rarityLegendary = Color(0xFFF59E0B); // 골드
  static const Color rarityLimited   = Color(0xFFEC4899); // 핑크

  // ── 랭킹 전용 ──────────────────────────────────────
  static const Color rankGold   = Color(0xFFF59E0B);
  static const Color rankSilver = Color(0xFF94A3B8);
  static const Color rankBronze = Color(0xFFB45309);

  // ── 그라디언트 ─────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFFD60A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient storeCardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient timerBgGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [Color(0xFF0D0B2E), Color(0xFF0C0C14)],
  );

  // ── 카드 데코레이션 헬퍼 ───────────────────────────
  static BoxDecoration get premiumCard => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderSubtle, width: 1),
  );

  static BoxDecoration storeItemCard({Color glowColor = rarityEpic}) =>
      BoxDecoration(
        gradient: storeCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glowColor.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      );

  static BoxDecoration get glowButton => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
        blurRadius: 20,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Context 기반 동적 색상 접근자 ────────────────────────
  static _AppColors of(BuildContext context) =>
      _AppColors(Theme.of(context).brightness == Brightness.dark);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF0F2FF),
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0x0F000000), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          elevation: 0,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 32, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: Color(0xFF1A1A2E), fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Color(0xFF5A5A6E), fontSize: 16),
        bodyLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF5A5A6E), fontSize: 14),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textSecondary,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}
