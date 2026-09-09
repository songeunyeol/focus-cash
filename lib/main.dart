import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'config/secrets.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/common/update_required_screen.dart';
import 'services/ad_service.dart';
import 'services/app_version_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: AppSecrets.kakaoNativeAppKey);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  try {
    final adService = AdService();
    await adService.initialize();
  } catch (e) {
    debugPrint('⚠️ 광고 초기화 실패 (무시): $e');
  }

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('⚠️ 알림 초기화 실패 (무시): $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 상태바 아이콘 밝기는 여기서 고정하지 않는다. DsTheme.appBarTheme 과
  // AppBar 없는 화면의 AnnotatedRegion 이 테마별로 결정한다.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const FocusCashApp());
}

class FocusCashApp extends StatelessWidget {
  const FocusCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FocusProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Focus Cash',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          scrollBehavior: const _NoGlowScrollBehavior(),
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const AppStartup(),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // 버전 확인은 스플래시 대기와 병렬로. 실패하면 막지 않는다 (AppVersionService 참고).
    final versionFuture = AppVersionService().check();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final version = await versionFuture;
    if (!mounted) return;
    if (version.isRequired) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => UpdateRequiredScreen(check: version),
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted =
        prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) return;

    if (!onboardingCompleted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    } else if (!authProvider.isLoggedIn) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    } else {
      await authProvider.loadUser();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.of(context).bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timer_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Focus Cash',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryColor,
                  ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppTheme.primaryColor,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}




