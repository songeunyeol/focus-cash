import 'package:flutter/material.dart';

import 'ds_colors.dart';
import 'ds_dimens.dart';
import 'ds_typography.dart';

/// ThemeData 조립.
///
/// 색은 [DsColors] 익스텐션이 들고, 여기서는 Material 위젯이 기본으로 집어가는
/// 값들만 맞춰둔다. 화면 코드가 `Theme.of(context).textTheme.*` 를 이미 쓰고 있어
/// 매핑만으로 상당수가 새 타입 스케일로 자동 이행된다.
abstract final class DsTheme {
  static const String _fontFamily = 'Pretendard';

  /// Pretendard 에는 이모지 글리프가 없다. 시스템 이모지 폰트로 폴백시킨다.
  static const List<String> _fallback = <String>[
    'Noto Color Emoji',
    'sans-serif',
  ];

  static ThemeData dark() => _build(DsColors.dark, Brightness.dark);

  static ThemeData light() => _build(DsColors.light, Brightness.light);

  static ThemeData _build(DsColors c, Brightness brightness) {
    final TextTheme text = _textTheme(c);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fallback,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.borderSubtle,
      extensions: <ThemeExtension<dynamic>>[c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.flame,
        onPrimary: c.onAccent,
        secondary: c.flameBright,
        onSecondary: c.onAccent,
        error: c.danger,
        onError: c.onAccent,
        surface: c.surface,
        onSurface: c.textPrimary,
        outline: c.borderDefault,
        outlineVariant: c.borderSubtle,
      ),
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: c.textPrimary,
        titleTextStyle: DsType.heading.on(c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: R.rMd,
          side: BorderSide(color: c.borderSubtle, width: Stroke.hairline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.flame,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceOverlay,
          disabledForegroundColor: c.textDisabled,
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x6,
            vertical: Sp.x3,
          ),
          shape: const RoundedRectangleBorder(borderRadius: R.rSm),
          textStyle: DsType.bodyStrong,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accentText,
          textStyle: DsType.bodyStrong,
          shape: const RoundedRectangleBorder(borderRadius: R.rSm),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.borderDefault, width: Stroke.hairline),
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.x6,
            vertical: Sp.x3,
          ),
          shape: const RoundedRectangleBorder(borderRadius: R.rSm),
          textStyle: DsType.bodyStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.flame,
        linearTrackColor: c.surfaceOverlay,
        circularTrackColor: c.surfaceOverlay,
      ),
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: Stroke.hairline,
        space: Stroke.hairline,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }

  /// 기존 화면이 이미 쓰고 있는 Material 역할에 새 스케일을 얹는다.
  /// (headlineMedium 은 호환을 위해 title 로 매핑한다)
  static TextTheme _textTheme(DsColors c) => TextTheme(
        displayLarge: DsType.display.on(c.textPrimary),
        displayMedium: DsType.display.on(c.textPrimary),
        headlineLarge: DsType.title.on(c.textPrimary),
        headlineMedium: DsType.title.on(c.textPrimary),
        headlineSmall: DsType.heading.on(c.textPrimary),
        titleLarge: DsType.heading.on(c.textPrimary),
        titleMedium: DsType.subhead.on(c.textPrimary),
        titleSmall: DsType.bodyStrong.on(c.textPrimary),
        bodyLarge: DsType.bodyStrong.on(c.textPrimary),
        bodyMedium: DsType.body.on(c.textSecondary),
        bodySmall: DsType.caption.on(c.textSecondary),
        labelLarge: DsType.bodyStrong.on(c.textPrimary),
        labelMedium: DsType.label.on(c.textSecondary),
        labelSmall: DsType.micro.on(c.textTertiary),
      );
}
