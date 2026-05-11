import 'package:flutter/material.dart';
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
import '../screens/profile/achievements_screen.dart';
import '../screens/profile/focus_calendar_screen.dart';

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
  static const String achievements = '/achievements';
  static const String focusCalendar = '/focus-calendar';

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
        return sharedAxisRoute(
          settings: settings,
          page: FocusScreen(
            focusMinutes: args['focusMinutes'] as int,
            hardcoreMode: args['hardcoreMode'] as String? ?? 'normal',
            tag: args['tag'] as String? ?? '',
            watchAdOnStart: args['watchAdOnStart'] as bool? ?? false,
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
      case achievements:
        return sharedAxisRoute(
            page: const AchievementsScreen(), settings: settings);
      case focusCalendar:
        return sharedAxisRoute(
            page: const FocusCalendarScreen(), settings: settings);
      default:
        return fadeThroughRoute(page: const HomeScreen(), settings: settings);
    }
  }
}
