import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Google 공식 테스트 ID (실제 과금 없음)
  // 출시 전: 아래 3개를 실제 AdMob ID로 교체
  static const String _testInterstitialId =
      'ca-app-pub-9438563541930346/6418161812';
  static const String _testRewardedId =
      'ca-app-pub-9438563541930346/7606152804';
  static const String testBannerId =
      'ca-app-pub-9438563541930346/3328964046';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
  }

  // ── 전면 광고 ──────────────────────────────────────────

  void loadInterstitialAd({
    required void Function() onAdLoaded,
    void Function()? onAdFailed,
  }) {
    if (kIsWeb) {
      onAdFailed?.call();
      return;
    }
    InterstitialAd.load(
      adUnitId: _testInterstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          onAdLoaded();
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          onAdFailed?.call();
        },
      ),
    );
  }

  Future<bool> showInterstitialAd({void Function()? onDismissed}) async {
    if (!_isInterstitialAdReady || _interstitialAd == null) return false;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialAdReady = false;
        onDismissed?.call();
      },
    );
    await _interstitialAd!.show();
    return true;
  }

  // ── 리워드 광고 ─────────────────────────────────────────

  void loadRewardedAd({
    void Function()? onAdLoaded,
    void Function()? onAdFailed,
  }) {
    if (kIsWeb) {
      onAdFailed?.call();
      return;
    }
    RewardedAd.load(
      adUnitId: _testRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          onAdFailed?.call();
        },
      ),
    );
  }

  /// 리워드 광고를 보여주고, 시청 완료 시 [onRewarded] 콜백을 호출
  /// 광고를 끝까지 보지 않고 닫은 경우 [onDismissedWithoutReward] 콜백을 호출
  Future<bool> showRewardedAd({
    required void Function() onRewarded,
    void Function()? onDismissedWithoutReward,
  }) async {
    if (!_isRewardedAdReady || _rewardedAd == null) return false;

    bool rewardEarned = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        loadRewardedAd();
        if (!rewardEarned) onDismissedWithoutReward?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        onDismissedWithoutReward?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        onRewarded();
      },
    );
    return true;
  }

  bool get isRewardedAdReady => _isRewardedAdReady;

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
