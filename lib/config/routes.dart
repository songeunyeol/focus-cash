import 'package:flutter/material.dart';
import '../design/ds_theme.dart';
import 'page_transitions.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_terms_screen.dart';
import '../screens/auth/signup_profile_screen.dart';
import '../screens/auth/signup_complete_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/focus/focus_screen.dart';
import '../screens/focus/focus_setup_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/ranking/ranking_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/records/records_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String signupTerms = '/signup-terms';
  static const String signupProfile = '/signup-profile';
  static const String signupComplete = '/signup-complete';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String focusSetup = '/focus-setup';
  static const String focus = '/focus';
  static const String store = '/store';
  static const String ranking = '/ranking';
  static const String profile = '/profile';

  /// 기록 (통계·캘린더·크레딧·업적). 인자 `{'tab': RecordsTab}` 로 초기 탭을 고른다.
  static const String records = '/records';

  /// 구 라우트 이름. 기록 화면의 해당 탭으로 연결된다.
  static const String achievements = '/achievements';
  static const String focusCalendar = '/focus-calendar';

  /// 기록 화면을 특정 탭으로 연다.
  static Future<void> openRecords(BuildContext context, RecordsTab tab) =>
      Navigator.of(context).pushNamed(records, arguments: {'tab': tab});

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return fadeThroughRoute(page: const LoginScreen(), settings: settings);
      case signupTerms:
        return sharedAxisRoute(
            page: const SignupTermsScreen(), settings: settings);
      case signupProfile:
        return sharedAxisRoute(
            page: const SignupProfileScreen(), settings: settings);
      case signupComplete:
        return sharedAxisRoute(
            page: const SignupCompleteScreen(), settings: settings);
      case onboarding:
        return fadeThroughRoute(
            page: const OnboardingScreen(), settings: settings);
      case home:
        return fadeThroughRoute(page: const HomeScreen(), settings: settings);
      case focusSetup:
        return sharedAxisRoute(
            page: const FocusSetupScreen(), settings: settings);
      case focus:
        final args = settings.arguments as Map<String, dynamic>;
        // 집중 화면은 테마 설정과 무관하게 항상 다크다.
        // OLED 에서 흰 배경은 전력 소모가 가장 크고, 120분짜리 화면이 바로 이 화면이다.
        // 밝기 저하만으로는 흰 픽셀의 소비를 못 줄이고, 토글은 대부분 건드리지 않는다.
        return sharedAxisRoute(
          settings: settings,
          page: Theme(
            data: DsTheme.dark(),
            child: FocusScreen(
              focusMinutes: args['focusMinutes'] as int,
              hardcoreMode: args['hardcoreMode'] as String? ?? 'normal',
              tag: args['tag'] as String? ?? '',
              watchAdOnStart: args['watchAdOnStart'] as bool? ?? false,
            ),
          ),
        );
      case store:
        return sharedAxisRoute(page: const StoreScreen(), settings: settings);
      case ranking:
        return sharedAxisRoute(
            page: const RankingScreen(), settings: settings);
      case profile:
        return sharedAxisRoute(
            page: const ProfileScreen(), settings: settings);
      case records:
        final args = settings.arguments;
        final tab = args is Map && args['tab'] is RecordsTab
            ? args['tab'] as RecordsTab
            : RecordsTab.stats;
        return sharedAxisRoute(
            page: RecordsScreen(initialTab: tab), settings: settings);
      case achievements:
        return sharedAxisRoute(
            page: const RecordsScreen(initialTab: RecordsTab.achievements),
            settings: settings);
      case focusCalendar:
        return sharedAxisRoute(
            page: const RecordsScreen(initialTab: RecordsTab.calendar),
            settings: settings);
      default:
        return fadeThroughRoute(page: const HomeScreen(), settings: settings);
    }
  }
}
