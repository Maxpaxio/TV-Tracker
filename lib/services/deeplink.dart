// lib/services/deeplink.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../models/show_models.dart';

/// Opens streaming providers with best-effort deep linking:
/// 1) Web: open provider universal link (iOS will route into app if installed)
/// 2) Native: try universal link first (more reliable), then app scheme, then fallback page.
class DeepLinker {
  static Future<void> open({
    required WatchProvider provider,
    required String showTitle,
    String? regionFallbackUrl, // e.g., TMDB/JustWatch region page
  }) async {
    final key = _classify(provider.name);
    final String? universal = _universalSearchUrl(key, showTitle);
    final String? scheme = _appScheme(key);

    // Web (PWA/browser) — just open universal link to avoid blank tabs.
    if (kIsWeb) {
      if (await _tryOpen(universal)) return;
      if (await _tryOpen(regionFallbackUrl)) return;
      return;
    }

    // Native (iOS/Android) — prefer universal link (app intercepts), then scheme, then fallback.
    if (await _tryOpen(universal)) return;
    if (await _tryOpen(scheme)) return;
    if (await _tryOpen(regionFallbackUrl)) return;
  }

  static Future<bool> _tryOpen(String? url) async {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok;
    }
    return false;
  }

  // ---- Provider classification
  static _Provider _classify(String name) {
    final n = name.toLowerCase();
    if (n.contains('netflix')) return _Provider.netflix;
    if (n.contains('disney')) return _Provider.disneyPlus;
    if (n.contains('max') || n.contains('hbo')) return _Provider.max;
    if (n.contains('hulu')) return _Provider.hulu;
    if (n.contains('prime') || n.contains('amazon'))
      return _Provider.primeVideo;
    if (n.contains('apple tv')) return _Provider.appleTV;
    if (n.contains('paramount')) return _Provider.paramountPlus;
    if (n.contains('peacock')) return _Provider.peacock;
    if (n.contains('viaplay')) return _Provider.viaplay;
    if (n.contains('svt')) return _Provider.svtPlay;
    if (n.contains('cmore')) return _Provider.cmore;
    if (n.contains('discovery+') ||
        n.contains('discovery plus') ||
        n.contains('max discovery'))
      return _Provider.discoveryPlus;
    if (n.contains('skyshowtime')) return _Provider.skyShowtime;
    return _Provider.generic;
  }

  // ---- Universal search URLs (apps usually intercept these)
  static String _enc(String s) => Uri.encodeComponent(s.trim());
  static String? _universalSearchUrl(_Provider p, String title) {
    final q = _enc(title);
    switch (p) {
      case _Provider.netflix:
        return 'https://www.netflix.com/search?q=$q';
      case _Provider.disneyPlus:
        return 'https://www.disneyplus.com/search/$q';
      case _Provider.max:
        return 'https://play.max.com/search?query=$q';
      case _Provider.hulu:
        return 'https://www.hulu.com/search?q=$q';
      case _Provider.primeVideo:
        return 'https://www.primevideo.com/search?phrase=$q';
      case _Provider.appleTV:
        return 'https://tv.apple.com/search?term=$q';
      case _Provider.paramountPlus:
        return 'https://www.paramountplus.com/search/?q=$q';
      case _Provider.peacock:
        return 'https://www.peacocktv.com/search?q=$q';
      case _Provider.viaplay:
        return 'https://www.viaplay.com/search?q=$q';
      case _Provider.svtPlay:
        return 'https://www.svtplay.se/sok?q=$q';
      case _Provider.cmore:
        return 'https://www.cmore.se/sok?q=$q';
      case _Provider.discoveryPlus:
        return 'https://www.discoveryplus.com/search?q=$q';
      case _Provider.skyShowtime:
        return 'https://www.skyshowtime.com/search?q=$q';
      case _Provider.generic:
        return null;
    }
  }

  // ---- App schemes (open app; not title-specific)
  static String? _appScheme(_Provider p) {
    switch (p) {
      case _Provider.netflix:
        return 'netflix://app';
      case _Provider.disneyPlus:
        return 'disneyplus://';
      case _Provider.max:
        return 'hbomax://';
      case _Provider.hulu:
        return 'hulu://';
      case _Provider.primeVideo:
        return 'primevideo://';
      case _Provider.appleTV:
        return 'tv://';
      case _Provider.paramountPlus:
        return 'paramountplus://';
      case _Provider.peacock:
        return 'peacock://';
      case _Provider.viaplay:
        return 'viaplay://';
      case _Provider.svtPlay:
        return 'svtplay://';
      case _Provider.cmore:
        return 'cmore://';
      case _Provider.discoveryPlus:
        return 'dplusapp://';
      case _Provider.skyShowtime:
        return null; // no stable public scheme
      case _Provider.generic:
        return null;
    }
  }
}

enum _Provider {
  netflix,
  disneyPlus,
  max,
  hulu,
  primeVideo,
  appleTV,
  paramountPlus,
  peacock,
  viaplay,
  svtPlay,
  cmore,
  discoveryPlus,
  skyShowtime,
  generic,
}
