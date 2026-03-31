import 'package:flutter/material.dart';
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

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        signupTerms: (context) => const SignupTermsScreen(),
        signupProfile: (context) => const SignupProfileScreen(),
        signupComplete: (context) => const SignupCompleteScreen(),
        onboarding: (context) => const OnboardingScreen(),
        home: (context) => const HomeScreen(),
        focusSetup: (context) => const FocusSetupScreen(),
        store: (context) => const StoreScreen(),
        ranking: (context) => const RankingScreen(),
        profile: (context) => const ProfileScreen(),
        achievements: (context) => const AchievementsScreen(),
        focusCalendar: (context) => const FocusCalendarScreen(),
      };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == focus) {
      final args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => FocusScreen(
          focusMinutes: args['focusMinutes'] as int,
          hardcoreMode: args['hardcoreMode'] as String? ?? 'normal',
          tag: args['tag'] as String? ?? '',
          watchAdOnStart: args['watchAdOnStart'] as bool? ?? false,
        ),
      );
    }
    if (settings.name == signupProfile) {
      return MaterialPageRoute(
        builder: (context) => const SignupProfileScreen(),
        settings: settings,
      );
    }
    return MaterialPageRoute(
      builder: (context) => const HomeScreen(),
    );
  }
}
