import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/show_models.dart';
import '../services/tmdb_api.dart';
import 'show_meta_page.dart';

class ShowDetailPage extends StatefulWidget {
  final int showId;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
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
  late TmdbApi api;
  Show? show;
  Map<String, dynamic>? detail;
  bool loading = true;
  String? overview;

  // Providers (region specific)
  List<WatchProvider> subs = const [];
  List<WatchProvider> rents = const [];
  List<WatchProvider> buys = const [];
  String? regionProviderPage; // TMDB/JustWatch page for this title in region

  String? backdropUrl;

  @override
  void initState() {
    super.initState();
    api = TmdbApi(widget.apiKey, region: widget.region);
    _bootstrap();
  }

  void _syncIntoParent() {
    if (show == null) return;
    final idx = widget.trackedShows.indexWhere((s) => s.tmdbId == show!.tmdbId);
    if (idx >= 0) {
      widget.trackedShows[idx] = show!;
    } else {
      widget.trackedShows.add(show!);
    }
  }

  Future<void> _bootstrap() async {
    try {
      show = widget.trackedShows.firstWhere(
        (s) => s.tmdbId == widget.showId,
        orElse: () => Show(
          tmdbId: widget.showId,
          title: 'Loading…',
          posterUrl: null,
          seasons: const [],
          isWatchlisted: false,
          subscriptionLogos: const [],
        ),
      );

      final d = await api.getShowDetail(widget.showId);
      final title = (d['name'] as String?)?.trim() ?? show!.title;
      final posterSmall = TmdbApi.imageUrl('w342', d['poster_path'] as String?);
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
      if (show!.seasons.isEmpty) {
        final seasons = await api.buildSeasonsWithEpisodeTitles(widget.showId);
        show = show!.copyWith(seasons: seasons);
      }

      // region providers
      final providersRaw = await api.getWatchProvidersRaw(widget.showId);
      regionProviderPage = api.extractRegionProviderPageLink(
        providersRaw,
        widget.region,
      );
      subs = api.extractFlatrateProviders(providersRaw, widget.region);
      rents = api.extractRentProviders(providersRaw, widget.region);
      buys = api.extractBuyProviders(providersRaw, widget.region);

      // keep small logo list for home badges (subs only)
      final subLogos = subs.map((e) => e.logoUrl).toList();
      final fallback = subLogos.isEmpty
          ? api.providerLogoFromDetail(d)
          : subLogos;
      show = show!.copyWith(subscriptionLogos: fallback);

      detail = d;
      _syncIntoParent();
      await widget.onTrackedShowsChanged();
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        overview = 'Failed to load details.';
      });
    }
  }

  Future<void> _persist() async {
    _syncIntoParent();
    await widget.onTrackedShowsChanged();
    if (mounted) setState(() {});
  }

  // ---- Exclusive states helpers ----
  List<Season> _allEpisodesWatched(bool watched) {
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
    final turningOn = !(show?.isWatchlisted ?? false);
    if (turningOn) {
      final cleared = _allEpisodesWatched(false);
      show = show!.copyWith(isWatchlisted: true, seasons: cleared);
    } else {
      show = show!.copyWith(isWatchlisted: false);
    }
    await _persist();
  }

  void _toggleShowWatched() async {
    final all = show!.allWatched;
    final updatedSeasons = _allEpisodesWatched(!all);
    show = show!.copyWith(seasons: updatedSeasons, isWatchlisted: false);
    await _persist();
  }

  void _toggleSeason(int seasonNumber, bool markWatched) async {
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

  // ---- Launch helpers ----

  Future<void> _openProvider(WatchProvider p) async {
    // 1) Try a native app scheme (best effort). This does NOT deep-link to the exact title,
    //     because TMDB doesn’t expose per-provider content IDs.
    final scheme = _schemeForProvider(p);
    if (scheme != null) {
      final uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }

    // 2) Try a provider website (home). Again, not title-specific.
    final web = _webForProvider(p);
    if (web != null) {
      final uri = Uri.parse(web);
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    }

    // 3) Fallback: region-specific “Where to Watch” page for this title (TMDB/JustWatch)
    if (regionProviderPage != null) {
      final uri = Uri.parse(regionProviderPage!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _schemeForProvider(WatchProvider p) {
    final n = p.name.toLowerCase();
    if (n.contains('netflix')) return 'netflix://app';
    if (n.contains('disney')) return 'disneyplus://';
    if (n.contains('hbo') || n == 'max') return 'hbomax://';
    if (n.contains('hulu')) return 'hulu://';
    if (n.contains('prime') || n.contains('amazon')) return 'primevideo://';
    if (n.contains('apple tv')) return 'tv://'; // may open Apple TV app on iOS
    if (n.contains('paramount')) return 'paramountplus://';
    if (n.contains('peacock')) return 'peacock://';
    if (n.contains('viaplay')) return 'viaplay://';
    if (n.contains('viafree')) return 'viafree://';
    if (n.contains('svt')) return 'svtplay://';
    if (n.contains('cmore')) return 'cmore://';
    if (n.contains('discovery+') || n.contains('discovery plus'))
      return 'dplusapp://';
    // Add more as you encounter them.
    return null;
    // Note: On Android you may want to use package names + Android intent URLs for better results.
  }

  String? _webForProvider(WatchProvider p) {
    final n = p.name.toLowerCase();
    if (n.contains('netflix')) return 'https://www.netflix.com/';
    if (n.contains('disney')) return 'https://www.disneyplus.com/';
    if (n.contains('hbo') || n == 'max') return 'https://play.max.com/';
    if (n.contains('hulu')) return 'https://www.hulu.com/';
    if (n.contains('prime') || n.contains('amazon'))
      return 'https://www.primevideo.com/';
    if (n.contains('apple tv')) return 'https://tv.apple.com/';
    if (n.contains('paramount')) return 'https://www.paramountplus.com/';
    if (n.contains('peacock')) return 'https://www.peacocktv.com/';
    if (n.contains('viaplay')) return 'https://viaplay.com/';
    if (n.contains('svt')) return 'https://www.svtplay.se/';
    if (n.contains('cmore')) return 'https://www.cmore.se/';
    if (n.contains('discovery+') || n.contains('discovery plus'))
      return 'https://www.discoveryplus.com/';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = show;

    final watchedCount = s?.watchedCount ?? 0;
    final total = s?.totalEpisodes ?? 0;
    final pct = (total > 0) ? ((s!.progress * 100).round()) : 0;

    return Scaffold(
      appBar: AppBar(title: Text(s?.title ?? 'Details'), centerTitle: true),
      body: loading || s == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Poster-left + right backdrop with left fade
                  SizedBox(
                    height: 260,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: backdropUrl != null
                              ? Image.network(backdropUrl!, fit: BoxFit.cover)
                              : const SizedBox.shrink(),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.0),
                                    Colors.black.withValues(alpha: 0.0),
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.black.withValues(alpha: 0.95),
                                  ],
                                  stops: const [0.0, 0.4, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: s.posterUrl != null
                                  ? Image.network(
                                      s.posterUrl!,
                                      width: 150,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 150,
                                      height: 220,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.tv),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ======= Content =======
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        if (s.totalEpisodes > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: s.progress),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Watched $watchedCount / $total  ($pct%)',
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
                                  s.title,
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: s.allWatched
                                  ? 'Unmark entire show'
                                  : 'Mark entire show as watched',
                              iconSize: 28,
                              onPressed: _toggleShowWatched,
                              icon: Icon(
                                s.allWatched
                                    ? Icons.check_circle
                                    : Icons.check_circle_outlined,
                                color: s.allWatched
                                    ? Colors.greenAccent
                                    : Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              tooltip: s.isWatchlisted
                                  ? 'Remove from watchlist'
                                  : 'Add to watchlist',
                              iconSize: 28,
                              onPressed: _toggleWatchlist,
                              icon: Icon(
                                s.isWatchlisted
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline,
                                color: s.isWatchlisted
                                    ? Colors.amber
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

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
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _logoChip(WatchProvider p) {
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
