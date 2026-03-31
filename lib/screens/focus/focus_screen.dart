import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/focus_provider.dart';
import '../../services/ad_service.dart';

class FocusScreen extends StatefulWidget {
  final int focusMinutes;
  final String hardcoreMode;
  final String tag;
  final bool watchAdOnStart;

  const FocusScreen({
    super.key,
    required this.focusMinutes,
    this.hardcoreMode = 'normal',
    this.tag = '',
    this.watchAdOnStart = false,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final AdService _adService = AdService();
  bool _creditsApplied = false;
  bool _rewardAdWatched = false;
  Timer? _backgroundTimer;
  FocusProvider? _focusProviderRef;

  late AnimationController _completedAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _completedAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(
      parent: _completedAnimController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _completedAnimController,
      curve: Curves.easeIn,
    );

    _initAds();
    _startSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusProviderRef = context.read<FocusProvider>();
      _focusProviderRef!.addListener(_onFocusStateChanged);
    });
  }

  @override
  void dispose() {
    _backgroundTimer?.cancel();
    _focusProviderRef?.removeListener(_onFocusStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _adService.dispose();
    _completedAnimController.dispose();
    super.dispose();
  }

  void _onFocusStateChanged() {
    if (!mounted) return;
    final focusProvider = context.read<FocusProvider>();

    if (focusProvider.state == FocusState.completed && !_creditsApplied) {
      _creditsApplied = true;
      // Firestore 저장이 완료된 후 최신 데이터를 다시 불러와 로컬 불일치 방지
      context.read<AuthProvider>().loadUser();
      _completedAnimController.forward();
    } else if (focusProvider.state == FocusState.abandoned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        focusProvider.reset();
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final focusProvider = context.read<FocusProvider>();

    if (state == AppLifecycleState.paused) {
      // 30초 유예 후 종료 (알림 확인, 전화 수신 등 단순 이탈 허용)
      if (focusProvider.state == FocusState.focusing) {
        _backgroundTimer = Timer(const Duration(seconds: 30), () {
          if (mounted && focusProvider.state == FocusState.focusing) {
            focusProvider.abandonSession();
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // 앱으로 복귀하면 유예 타이머 취소
      _backgroundTimer?.cancel();
      _backgroundTimer = null;
    }
  }

  void _initAds() {
    // 포기용 전면 광고 항상 미리 로드
    _adService.loadInterstitialAd(onAdLoaded: () {});

    if (widget.watchAdOnStart) {
      // 시작 광고: 리워드형으로 변경 (끝까지 봐야 보너스 지급)
      _adService.loadRewardedAd(
        onAdLoaded: () {
          _adService.showRewardedAd(
            onRewarded: () {
              if (mounted) {
                context.read<FocusProvider>().addStartAdBonus();
              }
            },
            // 중간에 닫으면 보너스 없음 (자동으로 다음 리워드 광고 재로드됨)
          );
        },
      );
    } else {
      // 광고 없이 시작 → 종료 보너스용 리워드 광고만 미리 로드
      _adService.loadRewardedAd();
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _startSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final user = context.read<AuthProvider>().user;
      if (user == null) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (r) => false,
        );
        return;
      }

      final online = await _hasNetwork();
      if (!mounted) return;
      if (!online) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인터넷 연결이 필요합니다. 네트워크를 확인해주세요.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      context.read<FocusProvider>().startFocus(
            userId: user.uid,
            targetMinutes: widget.focusMinutes,
            hardcoreMode: widget.hardcoreMode,
            tag: widget.tag,
            watchedStartAd: false, // 리워드 광고 완료 시 addStartAdBonus()로 별도 지급
          );
    });
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleAbandon() async {
    final focusProvider = context.read<FocusProvider>();
    final isHardcore = widget.hardcoreMode == 'hardcore';

    if (isHardcore) {
      // ── 하드코어: 마찰 다이얼로그 ────────────────────────────────────────
      final currentCredits =
          context.read<AuthProvider>().user?.totalCredits ?? 0;
      final penaltyCredits =
          (currentCredits * AppConstants.hardcorePenaltyRate).ceil();

      final result = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _HardcoreAbandonDialog(
          elapsedMinutes: focusProvider.elapsedMinutes,
          penaltyCredits: penaltyCredits,
        ),
      );

      if (!mounted) return;
      if (result == 1) {
        // 광고 보고 패널티 면제
        final shown = await _adService.showRewardedAd(
          onRewarded: () async {
            if (mounted) {
              await context.read<FocusProvider>().abandonSession(nopenalty: true);
            }
          },
          onDismissedWithoutReward: () async {
            // 광고 중간 닫기 → 패널티 없이 복귀 (다시 집중 기회)
          },
        );
        if (!shown && mounted) {
          await context.read<FocusProvider>().abandonSession();
        }
      } else if (result == 2 && mounted) {
        await context.read<FocusProvider>().abandonSession();
      }
    } else {
      // ── 일반 모드: 마찰 다이얼로그 ─────────────────────────────────────
      final elapsedMin = focusProvider.elapsedMinutes;
      final lostCredits = focusProvider.earnedCredits;

      final result = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _NormalAbandonDialog(
          elapsedMinutes: elapsedMin,
          lostCredits: lostCredits,
        ),
      );

      if (!mounted) return;
      if (result == 1) {
        // 8초 대기 후 전면 광고 → 포기
        final shown = await _adService.showInterstitialAd(
          onDismissed: () async {
            if (mounted) await context.read<FocusProvider>().abandonSession();
          },
        );
        if (!shown && mounted) {
          await context.read<FocusProvider>().abandonSession();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final focusProvider = context.watch<FocusProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && focusProvider.state == FocusState.focusing) {
          _handleAbandon();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: _buildBody(focusProvider),
        ),
      ),
    );
  }

  Widget _buildBody(FocusProvider provider) {
    switch (provider.state) {
      case FocusState.focusing:
        return _buildFocusingView(provider);
      case FocusState.completed:
        return _buildCompletedView(provider);
      case FocusState.abandoned:
        return _buildAbandonedView(provider);
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildFocusingView(FocusProvider provider) {
    return Column(
      children: [
        // 배너 1 - 최상단
        const _BannerAdWidget(size: AdSize.largeBanner),

        Expanded(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                const SizedBox(height: 12),

                // 과목 태그
                if (widget.tag.isNotEmpty)
                  Chip(
                    label: Text(widget.tag),
                    backgroundColor: AppTheme.accentGreen.withAlpha(30),
                    labelStyle: const TextStyle(color: AppTheme.accentGreen),
                  ),

                const SizedBox(height: 16),

                // 원형 타이머
                CircularPercentIndicator(
                  radius: 130,
                  lineWidth: 12,
                  percent: provider.progress.clamp(0.0, 1.0),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(provider.remainingSeconds),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${provider.elapsedMinutes}분 집중 중',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  progressColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.surfaceColor,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: false,
                ),

                const SizedBox(height: 16),

                // 테스트 버튼 (디버그)
                if (kDebugMode)
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.read<FocusProvider>().skipToComplete(),
                    icon: const Icon(Icons.fast_forward, size: 18),
                    label: const Text('[테스트] 즉시 완료'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondaryColor,
                      side: const BorderSide(color: AppTheme.secondaryColor),
                    ),
                  ),

                // 포기하기
                TextButton(
                  onPressed: _handleAbandon,
                  child: const Text(
                    '포기하기',
                    style: TextStyle(color: AppTheme.accentRed, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
            ),
          ),
        ),

        // 배너 2 - 최하단
        const _BannerAdWidget(size: AdSize.banner),
      ],
    );
  }

  Widget _buildCompletedView(FocusProvider provider) {
    final hours = widget.focusMinutes ~/ 60;
    final mins = widget.focusMinutes % 60;
    final timeStr = hours > 0
        ? '$hours시간${mins > 0 ? ' $mins분' : ''}'
        : '$mins분';

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 완료 아이콘 (애니메이션)
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.creditGold.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 56,
                  color: AppTheme.creditGold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              '집중 완료! 🎉',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$timeStr 동안 집중했어요',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 28),

            // 통계 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.timer,
                    label: '집중 시간',
                    value: timeStr,
                    color: AppTheme.primaryColor,
                  ),
                  const Divider(color: AppTheme.surfaceColor, height: 24),
                  _StatRow(
                    icon: Icons.monetization_on,
                    label: '획득 크레딧',
                    value: '+${provider.earnedCredits}',
                    color: AppTheme.creditGold,
                  ),
                  if (widget.tag.isNotEmpty) ...[
                    const Divider(color: AppTheme.surfaceColor, height: 24),
                    _StatRow(
                      icon: Icons.label,
                      label: '과목',
                      value: widget.tag,
                      color: AppTheme.accentGreen,
                    ),
                  ],
                  if (widget.hardcoreMode != 'normal') ...[
                    const Divider(color: AppTheme.surfaceColor, height: 24),
                    _StatRow(
                      icon: Icons.local_fire_department,
                      label: '모드',
                      value: widget.hardcoreMode == 'hardcore'
                          ? '하드코어'
                          : '울트라',
                      color: AppTheme.accentRed,
                    ),
                  ],
                  if (provider.earnedXp > 0) ...[
                    const Divider(color: AppTheme.surfaceColor, height: 24),
                    _StatRow(
                      icon: Icons.auto_awesome,
                      label: '획득 XP',
                      value: '+${provider.earnedXp} XP',
                      color: AppTheme.secondaryColor,
                    ),
                  ],
                ],
              ),
            ),

            // 레벨업 배너
            if (provider.newLevel > 0) ...[
              const SizedBox(height: 16),
              _LevelUpBanner(newLevel: provider.newLevel),
            ],

            // 새 배지 획득
            if (provider.newBadges.isNotEmpty) ...[
              const SizedBox(height: 16),
              _NewBadgesCard(badgeIds: provider.newBadges),
            ],

            const SizedBox(height: 20),

            // 리워드 광고 보너스 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _rewardAdWatched
                    ? null
                    : () {
                        _adService.showRewardedAd(
                          onRewarded: () {
                            provider.addEndAdBonus();
                            setState(() => _rewardAdWatched = true);
                            if (mounted) {
                              provider.reset();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                  AppRoutes.home, (r) => false);
                            }
                          },
                        );
                      },
                icon: const Icon(Icons.card_giftcard),
                label: Text(
                  _rewardAdWatched
                      ? '보너스 수령 완료!'
                      : '🎁 광고 보고 +${(provider.earnedCredits * AppConstants.endAdMultiplierRate).round()} 보너스',
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _rewardAdWatched
                      ? AppTheme.surfaceColor
                      : AppTheme.secondaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 다시 집중하기 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  provider.reset();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.focusSetup,
                    (r) => r.settings.name == AppRoutes.home,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text(
                  '다시 집중하기',
                  style: TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: () {
                provider.reset();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
              },
              child: const Text(
                '홈으로 돌아가기',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAbandonedView(FocusProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied,
                size: 80, color: AppTheme.accentRed),
            const SizedBox(height: 24),
            const Text(
              '집중 포기',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${provider.elapsedMinutes}분 집중했어요.\n다음엔 더 잘 할 수 있을 거예요!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () {
                provider.reset();
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
              },
              child: const Text('홈으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// 완료 화면 통계 행
// ────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────
// 배너 광고 위젯
// ────────────────────────────────────────────
class _BannerAdWidget extends StatefulWidget {
  final AdSize size;
  const _BannerAdWidget({this.size = AdSize.banner});

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdService.testBannerId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// ────────────────────────────────────────────
// 레벨업 배너
// ────────────────────────────────────────────
class _LevelUpBanner extends StatelessWidget {
  final int newLevel;
  const _LevelUpBanner({required this.newLevel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            child: Center(
              child: Text(
                '$newLevel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '레벨 업!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Lv.$newLevel · ${AppConstants.titleForLevel(newLevel)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_upward_rounded,
              color: Colors.white, size: 22),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// 새 배지 획득 카드
// ────────────────────────────────────────────
class _NewBadgesCard extends StatelessWidget {
  final List<String> badgeIds;
  const _NewBadgesCard({required this.badgeIds});

  @override
  Widget build(BuildContext context) {
    final badges = badgeIds
        .map((id) => AppConstants.badgeById(id))
        .where((b) => b != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (badges.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.creditGold.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.creditGold.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.creditGold, size: 18),
              const SizedBox(width: 8),
              Text(
                '새 배지 ${badges.length}개 획득!',
                style: const TextStyle(
                  color: AppTheme.creditGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges.map((b) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.creditGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.creditGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(b['icon'] as String,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      b['name'] as String,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────
// 일반 모드 포기 다이얼로그 (마찰 UX)
// ────────────────────────────────────────────
class _NormalAbandonDialog extends StatefulWidget {
  final int elapsedMinutes;
  final int lostCredits;

  const _NormalAbandonDialog({
    required this.elapsedMinutes,
    required this.lostCredits,
  });

  @override
  State<_NormalAbandonDialog> createState() => _NormalAbandonDialogState();
}

class _NormalAbandonDialogState extends State<_NormalAbandonDialog> {
  static const _countdownSeconds = 8;
  int _remaining = _countdownSeconds;
  Timer? _timer;

  String get _message {
    switch (_remaining) {
      case 8: return '조금만 더 버텨봐요';
      case 7: return '여기까지 왔는데...';
      case 6:
        return widget.lostCredits > 0
            ? '${widget.lostCredits} 크레딧이 사라져요'
            : '포기하면 후회할 것 같아요';
      case 5: return '포기하면 후회할 것 같아요';
      case 4: return '딱 한 번만 더 생각해봐요';
      case 3: return '진짜 포기할 거예요?';
      case 2: return '마지막 기회예요';
      case 1: return '...';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAbandon = _remaining == 0;

    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('집중을 포기할까요?',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 손실 크레딧 강조 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  widget.elapsedMinutes == 0
                      ? '막 시작했는데 벌써요?'
                      : '${widget.elapsedMinutes}분 집중 중',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.lostCredits == 0
                      ? '아직 쌓인 크레딧은 없지만\n집중 기록이 사라집니다'
                      : '${widget.lostCredits} 크레딧이 사라집니다',
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // 카운트다운 메시지
          if (_remaining > 0) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _message,
                key: ValueKey(_remaining),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      actions: [
        // 계속 집중
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('계속 집중',
              style: TextStyle(color: AppTheme.primaryColor)),
        ),
        // 그냥 포기 (카운트다운)
        TextButton(
          onPressed: canAbandon ? () => Navigator.of(context).pop(1) : null,
          child: Text(
            canAbandon ? '그냥 포기' : '그냥 포기 ($_remaining)',
            style: TextStyle(
              color: canAbandon
                  ? AppTheme.accentRed
                  : AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────
// 하드코어 모드 포기 다이얼로그 (마찰 UX)
// ────────────────────────────────────────────
class _HardcoreAbandonDialog extends StatefulWidget {
  final int elapsedMinutes;
  final int penaltyCredits;

  const _HardcoreAbandonDialog({
    required this.elapsedMinutes,
    required this.penaltyCredits,
  });

  @override
  State<_HardcoreAbandonDialog> createState() => _HardcoreAbandonDialogState();
}

class _HardcoreAbandonDialogState extends State<_HardcoreAbandonDialog> {
  static const _countdownSeconds = 8;
  int _remaining = _countdownSeconds;
  Timer? _timer;

  String get _message {
    switch (_remaining) {
      case 8: return '조금만 더 버텨봐요';
      case 7: return '여기까지 왔는데...';
      case 6:
        return widget.penaltyCredits > 0
            ? '${widget.penaltyCredits} 크레딧이 차감됩니다'
            : '포기하면 후회할 것 같아요';
      case 5: return '포기하면 후회할 것 같아요';
      case 4: return '딱 한 번만 더 생각해봐요';
      case 3: return '진짜 포기할 거예요?';
      case 2: return '마지막 기회예요';
      case 1: return '...';
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAbandon = _remaining == 0;

    return AlertDialog(
      backgroundColor: AppTheme.cardColor,
      title: const Text('집중을 포기할까요?',
          style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 패널티 강조 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department,
                        color: AppTheme.accentRed.withValues(alpha: 0.8),
                        size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.elapsedMinutes == 0
                          ? '막 시작했는데 벌써요?'
                          : '${widget.elapsedMinutes}분 집중 중 · 하드코어',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.penaltyCredits == 0
                      ? '보유 크레딧의 10%가\n차감됩니다'
                      : '${widget.penaltyCredits} 크레딧 차감',
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.penaltyCredits > 0) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '광고를 보면 면제받을 수 있어요',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          // 카운트다운 메시지
          if (_remaining > 0) ...[
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _message,
                key: ValueKey(_remaining),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      actions: [
        // 계속 집중
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('계속 집중',
              style: TextStyle(color: AppTheme.primaryColor)),
        ),
        // 광고 보고 패널티 면제
        TextButton(
          onPressed: () => Navigator.of(context).pop(1),
          child: const Text('광고로 면제',
              style: TextStyle(color: AppTheme.creditGold)),
        ),
        // 그냥 포기 (카운트다운)
        TextButton(
          onPressed: canAbandon ? () => Navigator.of(context).pop(2) : null,
          child: Text(
            canAbandon ? '그냥 포기' : '그냥 포기 ($_remaining)',
            style: TextStyle(
              color: canAbandon
                  ? AppTheme.accentRed
                  : AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
