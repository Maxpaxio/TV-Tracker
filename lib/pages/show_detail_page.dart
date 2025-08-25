// lib/pages/show_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/show_models.dart' as models; // alias your models
import '../services/tmdb_api.dart' as tmdb; // alias TMDB service
import '../services/deeplink.dart';
import 'show_meta_page.dart';

class ShowDetailPage extends StatefulWidget {
  final int showId;
  final String apiKey;
  final String region;
  final List<models.Show> trackedShows;
  final Future<void> Function() onTrackedShowsChanged;

  const ShowDetailPage({
    super.key,
    required this.showId,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  State<ShowDetailPage> createState() => _ShowDetailPageState();
}

class _ShowDetailPageState extends State<ShowDetailPage> {
  late tmdb.TmdbApi api;

  models.Show? show;
  Map<String, dynamic>? detail;

  bool loadingCore = true; // title/poster/providers
  bool loadingSeasons = true; // seasons
  String? overview;
  String? backdropUrl;
  Color _edgeColor = const Color(0xFF111113);

  // region-scoped providers (use your app model)
  List<models.WatchProvider> subs = const [];
  List<models.WatchProvider> rents = const [];
  List<models.WatchProvider> buys = const [];
  String? regionProviderPage;

  // layout
  static const double _posterW = 150.0;
  static const double _posterH = 220.0;
  static const double _hPad = 16.0;
  static const double _bannerH = 260.0;
  static const double _fadeIntoArtwork = 110.0;

  @override
  void initState() {
    super.initState();
    api = tmdb.TmdbApi(widget.apiKey, region: widget.region);
    _loadCoreFirst();
    _prewarmExtrasLater();
  }

  // -------- bootstrap / data --------
  void _syncIntoParent() {
    if (show == null) return;
    final idx = widget.trackedShows.indexWhere((s) => s.tmdbId == show!.tmdbId);
    if (idx >= 0) {
      widget.trackedShows[idx] = show!;
    } else {
      widget.trackedShows.add(show!);
    }
  }

  Future<void> _loadCoreFirst() async {
    try {
      show = widget.trackedShows.firstWhere(
        (s) => s.tmdbId == widget.showId,
        orElse: () => models.Show(
          tmdbId: widget.showId,
          title: 'Loading…',
          posterUrl: null,
          seasons: const [],
          isWatchlisted: false,
          subscriptionLogos: const [],
        ),
      );

      final results = await Future.wait([
        api.getShowDetail(widget.showId),
        api.getWatchProvidersRaw(widget.showId),
      ]);

      final d = results[0] as Map<String, dynamic>;
      final providersRaw = results[1] as Map<String, dynamic>;

      final title = (d['name'] as String?)?.trim() ?? show!.title;
      final posterSmall = tmdb.TmdbApi.imageUrl(
        'w342',
        d['poster_path'] as String?,
      );
      final desc = (d['overview'] as String?)?.trim();
      overview = (desc == null || desc.isEmpty)
          ? 'No description available.'
          : desc;
      backdropUrl = api.backdropUrlFromDetail(d, size: 'w1280');

      if (show!.posterUrl == null && posterSmall != null) {
        show = show!.copyWith(posterUrl: posterSmall);
      }
      if (show!.title == 'Loading…') {
        show = show!.copyWith(title: title);
      }

      // Providers for region — map TMDB providers to your app model
      regionProviderPage = api.extractRegionProviderPageLink(
        providersRaw,
        widget.region,
      );

      final subsRaw = api.extractFlatrateProviders(
        providersRaw,
        widget.region,
      ); // List<tmdb.WatchProvider>
      final rentsRaw = api.extractRentProviders(
        providersRaw,
        widget.region,
      ); // List<tmdb.WatchProvider>
      final buysRaw = api.extractBuyProviders(
        providersRaw,
        widget.region,
      ); // List<tmdb.WatchProvider>

      // tmdb.WatchProvider likely has: id, name, logoUrl (no webUrl). Don’t reference webUrl here.
      subs = subsRaw
          .map(
            (p) => models.WatchProvider(
              id: p.id,
              name: p.name,
              logoUrl: p.logoUrl,
            ),
          )
          .toList();
      rents = rentsRaw
          .map(
            (p) => models.WatchProvider(
              id: p.id,
              name: p.name,
              logoUrl: p.logoUrl,
            ),
          )
          .toList();
      buys = buysRaw
          .map(
            (p) => models.WatchProvider(
              id: p.id,
              name: p.name,
              logoUrl: p.logoUrl,
            ),
          )
          .toList();

      // Small set of subscription logos on the model (used on home badges)
      final subLogos = subs.map((e) => e.logoUrl).toList(); // List<String>

      // providerLogoFromDetail may return String OR List<String> (depending on your tmdb_api)
      List<String> fallback = const [];
      final dynamic pl = api.providerLogoFromDetail(d);
      if (pl is String) {
        fallback = [pl];
      } else if (pl is List) {
        fallback = pl.map((e) => e.toString()).toList();
      }

      final logosToUse = subLogos.isNotEmpty ? subLogos : fallback;
      show = show!.copyWith(subscriptionLogos: logosToUse);

      detail = d;
      _syncIntoParent();
      await widget.onTrackedShowsChanged();

      if (!mounted) return;
      setState(() => loadingCore = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingCore = false);
    }
  }

  Future<void> _prewarmExtrasLater() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // seasons
      if (show != null && show!.seasons.isEmpty) {
        try {
          final seasons = await api.buildSeasonsWithEpisodeTitles(
            widget.showId,
          );
          show = show!.copyWith(seasons: seasons);
          _syncIntoParent();
          await widget.onTrackedShowsChanged();
        } catch (_) {}
      }
      if (mounted) setState(() => loadingSeasons = false);

      // palette color
      final url = backdropUrl;
      if (url != null && url.isNotEmpty) {
        try {
          final pal = await PaletteGenerator.fromImageProvider(
            NetworkImage(url),
            maximumColorCount: 12,
          );
          final c =
              pal.dominantColor?.color ??
              pal.mutedColor?.color ??
              pal.darkMutedColor?.color;
          if (c != null && mounted) setState(() => _edgeColor = c);
        } catch (_) {}
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      loadingCore = true;
      loadingSeasons = true;
    });
    if (show != null) show = show!.copyWith(seasons: const []);
    await _loadCoreFirst();
    await _prewarmExtrasLater();
  }

  Future<void> _persist() async {
    _syncIntoParent();
    await widget.onTrackedShowsChanged();
    if (mounted) setState(() {});
  }

  // -------- state transitions (exclusive categories) --------
  List<models.Season> _allEpisodesWatched(bool watched) {
    return show!.seasons
        .map(
          (s) => s.copyWith(
            episodes: s.episodes
                .map((e) => e.copyWith(watched: watched))
                .toList(),
          ),
        )
        .toList();
  }

  void _toggleWatchlist() async {
    Feedback.forTap(context);
    final turnOn = !(show?.isWatchlisted ?? false);
    if (turnOn) {
      final cleared = _allEpisodesWatched(false);
      show = show!.copyWith(isWatchlisted: true, seasons: cleared);
    } else {
      show = show!.copyWith(isWatchlisted: false);
    }
    await _persist();
  }

  void _toggleShowWatched() async {
    Feedback.forTap(context);
    final all = show!.allWatched;
    final updated = _allEpisodesWatched(!all);
    show = show!.copyWith(seasons: updated, isWatchlisted: false);
    await _persist();
  }

  void _toggleSeason(int seasonNumber, bool markWatched) async {
    Feedback.forTap(context);
    final updated = show!.seasons.map((s) {
      if (s.number != seasonNumber) return s;
      return s.copyWith(
        episodes: s.episodes
            .map((e) => e.copyWith(watched: markWatched))
            .toList(),
      );
    }).toList();
    show = show!.copyWith(seasons: updated, isWatchlisted: false);
    await _persist();
  }

  void _toggleEpisode(int seasonNumber, int episodeNumber, bool watched) async {
    Feedback.forTap(context);
    final updated = show!.seasons.map((s) {
      if (s.number != seasonNumber) return s;
      return s.copyWith(
        episodes: s.episodes
            .map(
              (e) =>
                  e.number == episodeNumber ? e.copyWith(watched: watched) : e,
            )
            .toList(),
      );
    }).toList();
    show = show!.copyWith(seasons: updated, isWatchlisted: false);
    await _persist();
  }

  // -------- deep links --------
  Future<void> _openProvider(models.WatchProvider provider) async {
    await DeepLinker.open(
      provider: provider,
      showTitle: show?.title ?? '',
      regionFallbackUrl: regionProviderPage,
    );
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final s = show;

    final total = s?.totalEpisodes ?? 0;
    final pct = (total > 0 && s != null) ? ((s.progress * 100).round()) : 0;

    return Scaffold(
      appBar: AppBar(title: Text(s?.title ?? 'Details'), centerTitle: true),
      body: loadingCore && s == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              edgeOffset: 0,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ======= HERO =======
                  SizedBox(
                    height: _bannerH,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double screenW = constraints.maxWidth;
                        final double posterCenterX = _hPad + (_posterW / 2);
                        final double rightPad = _hPad;
                        final double artLeft = posterCenterX;
                        final double artRight = rightPad;

                        return Stack(
                          children: [
                            // Solid side panels
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              width: artLeft.clamp(0.0, screenW),
                              child: ColoredBox(color: _edgeColor),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: artRight.clamp(0.0, screenW),
                              child: ColoredBox(color: _edgeColor),
                            ),

                            // Artwork
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: artLeft,
                              right: artRight,
                              child: backdropUrl != null
                                  ? Center(
                                      child: CachedNetworkImage(
                                        imageUrl: backdropUrl!,
                                        height: _bannerH,
                                        fit: BoxFit.fitHeight,
                                        fadeInDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // Inner fades (use withValues to avoid deprecation)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: artLeft,
                              width: _fadeIntoArtwork,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        _edgeColor,
                                        _edgeColor.withValues(alpha: 0.7),
                                        _edgeColor.withValues(alpha: 0.35),
                                        _edgeColor.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.35, 0.7, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: artRight,
                              width: _fadeIntoArtwork,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        _edgeColor,
                                        _edgeColor.withValues(alpha: 0.7),
                                        _edgeColor.withValues(alpha: 0.35),
                                        _edgeColor.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.35, 0.7, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Poster
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _hPad,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: s?.posterUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: s!.posterUrl!,
                                          width: _posterW,
                                          height: _posterH,
                                          fit: BoxFit.cover,
                                          fadeInDuration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          placeholder: (_, __) =>
                                              Container(color: Colors.white12),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.tv),
                                        )
                                      : Container(
                                          width: _posterW,
                                          height: _posterH,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(Icons.tv),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // ======= CONTENT =======
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        if (s != null && s.totalEpisodes > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: s.progress),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Watched ${s.watchedCount} / ${s.totalEpisodes}  ($pct%)',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShowMetaPage(
                                  showId: widget.showId,
                                  apiKey: widget.apiKey,
                                  region: widget.region,
                                  trackedShows: widget.trackedShows,
                                  onTrackedShowsChanged:
                                      widget.onTrackedShowsChanged,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s?.title ?? '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  overview ?? 'No description available.',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (subs.isNotEmpty ||
                            rents.isNotEmpty ||
                            buys.isNotEmpty) ...[
                          const Text(
                            'Where to watch',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (subs.isNotEmpty) ...[
                            const Text(
                              'Subscription',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subs.map((p) => _logoChip(p)).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (rents.isNotEmpty) ...[
                            const Text(
                              'Rent',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: rents.map((p) => _logoChip(p)).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (buys.isNotEmpty) ...[
                            const Text(
                              'Buy',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: buys.map((p) => _logoChip(p)).toList(),
                            ),
                          ],
                        ],

                        const SizedBox(height: 16),
                        Divider(color: Colors.white.withValues(alpha: 0.12)),
                        const SizedBox(height: 8),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _toggleShowWatched,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  s?.allWatched == true
                                      ? Icons.check_circle
                                      : Icons.check_circle_outlined,
                                  size: 28,
                                  color: s?.allWatched == true
                                      ? Colors.greenAccent
                                      : Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _toggleWatchlist,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Icon(
                                  s?.isWatchlisted == true
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  size: 28,
                                  color: s?.isWatchlisted == true
                                      ? Colors.amber
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Seasons (simple ExpansionTiles)
                        if (!loadingSeasons &&
                            s != null &&
                            s.seasons.isNotEmpty)
                          ...s.seasons.map((season) {
                            final seasonAllWatched =
                                season.episodes.isNotEmpty &&
                                season.episodes.every((e) => e.watched);
                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Text(
                                    'Season ${season.number}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _toggleSeason(
                                      season.number,
                                      !seasonAllWatched,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        seasonAllWatched
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        size: 20,
                                        color: seasonAllWatched
                                            ? Colors.greenAccent
                                            : Colors.white60,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: season.episodes.map((ep) {
                                return CheckboxListTile(
                                  value: ep.watched,
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (v) => _toggleEpisode(
                                    season.number,
                                    ep.number,
                                    v ?? false,
                                  ),
                                  title: Text(
                                    'Ep ${ep.number}. ${ep.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            );
                          }),

                        if (loadingSeasons)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Loading seasons…',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _logoChip(models.WatchProvider p) {
    return InkWell(
      onTap: () => _openProvider(p),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(p.logoUrl, fit: BoxFit.contain),
      ),
    );
  }
}
