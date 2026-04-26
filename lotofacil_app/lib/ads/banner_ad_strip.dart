import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

bool get _isMobileSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

const bool kAdsEnabled = bool.fromEnvironment(
  'ADS_ENABLED',
  defaultValue: false,
);
const bool kAdsTestMode = bool.fromEnvironment(
  'ADS_TEST_MODE',
  defaultValue: true,
);
const bool kUseLargeBanner = bool.fromEnvironment(
  'ADS_LARGE_BANNER',
  defaultValue: true,
);
const String kAndroidBannerAdUnitId = String.fromEnvironment(
  'ANDROID_BANNER_AD_UNIT_ID',
  defaultValue: '',
);
const String kIosBannerAdUnitId = String.fromEnvironment(
  'IOS_BANNER_AD_UNIT_ID',
  defaultValue: '',
);
const String kAndroidRewardedAdUnitId = String.fromEnvironment(
  'ANDROID_REWARDED_AD_UNIT_ID',
  defaultValue: '',
);
const String kIosRewardedAdUnitId = String.fromEnvironment(
  'IOS_REWARDED_AD_UNIT_ID',
  defaultValue: '',
);
const String kGoogleTestAndroidBannerAdUnitId =
    'ca-app-pub-3940256099942544/6300978111';
const String kGoogleTestIosBannerAdUnitId =
    'ca-app-pub-3940256099942544/2934735716';
const String kGoogleTestAndroidRewardedAdUnitId =
    'ca-app-pub-3940256099942544/5224354917';
const String kGoogleTestIosRewardedAdUnitId =
    'ca-app-pub-3940256099942544/1712485313';

Future<void> initializeMobileAds() async {
  if (!kAdsEnabled || !_isMobileSupported) return;
  await MobileAds.instance.initialize();
}

Future<bool> showFullscreenRewardedAdGate(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!kAdsEnabled) return true;
  if (!_isMobileSupported) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Anuncios em video exigem Android/iOS.'),
      ),
    );
    return false;
  }

  final unitId = _resolveRewardedUnitId();
  if (unitId == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Unidade de anuncio em video nao configurada.'),
      ),
    );
    return false;
  }

  final completer = Completer<bool>();
  bool earned = false;

  await RewardedAd.load(
    adUnitId: unitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            if (!completer.isCompleted) {
              completer.complete(earned);
            }
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        );

        ad.show(
          onUserEarnedReward: (ad, reward) {
            earned = true;
          },
        );
      },
      onAdFailedToLoad: (error) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    ),
  );

  final unlocked = await completer.future;
  if (!unlocked) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Assista ao video completo para liberar as combinacoes.'),
      ),
    );
  }
  return unlocked;
}

String? _resolveRewardedUnitId() {
  if (!(Platform.isAndroid || Platform.isIOS)) return null;
  if (kAdsTestMode) {
    if (Platform.isAndroid) return kGoogleTestAndroidRewardedAdUnitId;
    if (Platform.isIOS) return kGoogleTestIosRewardedAdUnitId;
  }
  if (Platform.isAndroid && kAndroidRewardedAdUnitId.isNotEmpty) {
    return kAndroidRewardedAdUnitId;
  }
  if (Platform.isIOS && kIosRewardedAdUnitId.isNotEmpty) {
    return kIosRewardedAdUnitId;
  }
  return null;
}

class BannerAdStrip extends StatefulWidget {
  const BannerAdStrip({super.key});

  @override
  State<BannerAdStrip> createState() => _BannerAdStripState();
}

class _BannerAdStripState extends State<BannerAdStrip> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBannerIfEnabled();
  }

  Future<void> _loadBannerIfEnabled() async {
    if (!_isMobileSupported) return;
    final unitId = _resolveBannerUnitId();
    if (unitId == null) return;

    setState(() {
      _loading = true;
      _loadError = null;
    });

    final banner = BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: kUseLargeBanner ? AdSize.largeBanner : AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _loaded = true;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _loaded = false;
            _loading = false;
            _loadError = error.message;
          });
        },
      ),
    );

    await banner.load();
  }

  String? _resolveBannerUnitId() {
    if (!kAdsEnabled) return null;
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    if (kAdsTestMode) {
      if (Platform.isAndroid) return kGoogleTestAndroidBannerAdUnitId;
      if (Platform.isIOS) return kGoogleTestIosBannerAdUnitId;
    }
    if (Platform.isAndroid && kAndroidBannerAdUnitId.isNotEmpty) {
      return kAndroidBannerAdUnitId;
    }
    if (Platform.isIOS && kIosBannerAdUnitId.isNotEmpty) {
      return kIosBannerAdUnitId;
    }
    return null;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kAdsEnabled) {
      return const SizedBox.shrink();
    }

    if (!_isMobileSupported) {
      if (!kAdsTestMode) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            'AdMob teste: plataforma sem suporte para banner (use Android/iOS).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    if (!_loaded || _bannerAd == null) {
      if (!kAdsTestMode) return const SizedBox.shrink();
      final status = _loading
          ? 'Carregando banner de teste...'
          : (_loadError == null
              ? 'Banner de teste aguardando carregamento...'
              : 'Falha ao carregar banner de teste: $_loadError');
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kAdsTestMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Anuncio em modo de teste',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ],
        ),
      ),
    );
  }
}
