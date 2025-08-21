// lib/pages/show_detail_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/show_models.dart';
import '../services/tmdb_api.dart';

class ShowDetailPage extends StatefulWidget {
  final int showId;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final VoidCallback onTrackedShowsChanged;
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
  late final TmdbApi tmdb;
  Map<String, dynamic>? showData;
  Map<String, dynamic> providers = {};
  bool loading = true;
  Show? trackedShow;

  @override
  void initState() {
    super.initState();
    tmdb = TmdbApi(widget.apiKey, region: widget.region);
    _init();
  }

  Future<void> _init() async {
    final data = await tmdb.getShowDetail(widget.showId);
    if (data == null) {
      setState(() => loading = false);
      return;
    }

    final seasons = await tmdb.buildSeasonsWithEpisodeTitles(
      widget.showId,
      (data["seasons"] as List<dynamic>? ?? []),
    );

    final existing = widget.trackedShows.firstWhere(
      (s) => s.tmdbId == widget.showId,
      orElse: () => Show.empty(),
    );

    if (existing.tmdbId != -1) {
      for (final ns in seasons) {
        final os = existing.seasons.firstWhere(
          (s) => s.number == ns.number,
          orElse: () => Season(number: ns.number, episodes: []),
        );
        for (final ne in ns.episodes) {
          final oe = os.episodes.firstWhere(
            (e) => e.number == ne.number,
            orElse: () => Episode(number: ne.number, title: ne.title),
          );
          ne.watched = oe.watched;
        }
      }
      existing.seasons = seasons;
      existing.platformLogoUrl ??= tmdb.providerLogoFromDetail(data);
      existing.posterUrl ??= tmdb.posterUrlSmallFromDetail(data);
      trackedShow = existing;
    } else {
      trackedShow = Show(
        tmdbId: widget.showId,
        title: data["name"] ?? "Untitled",
        seasons: seasons,
        posterUrl: tmdb.posterUrlSmallFromDetail(data),
        platformLogoUrl: tmdb.providerLogoFromDetail(data),
      );
      widget.trackedShows.add(trackedShow!);
    }

    // Fetch providers and SAVE subscription logos to the model (used on homepage)
    final prov = await tmdb.getWatchProviders(widget.showId);
    final logos = tmdb.extractFlatrateLogos(prov, max: 4);
    trackedShow!.subscriptionLogos = logos;

    setState(() {
      showData = data;
      providers = prov;
      loading = false;
    });

    widget.onTrackedShowsChanged(); // persist updated show with logos
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _toggleEntireShowWatched() {
    if (trackedShow == null) return;
    setState(() {
      final isAllWatched = trackedShow!.allWatched;
      for (final s in trackedShow!.seasons) {
        for (final e in s.episodes) {
          e.watched = !isAllWatched;
        }
      }
      if (trackedShow!.allWatched) {
        trackedShow!.isWatchlisted = false;
      }
    });
    widget.onTrackedShowsChanged();
  }

  void _toggleWatchlist() {
    if (trackedShow == null) return;
    setState(() {
      trackedShow!.isWatchlisted = !trackedShow!.isWatchlisted;
      if (trackedShow!.allWatched) {
        trackedShow!.isWatchlisted = false;
      }
    });
    widget.onTrackedShowsChanged();
  }

  Widget _logoPill(
    String? logoUrl, {
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: logoUrl == null
            ? const Icon(Icons.ondemand_video, size: 20)
            : Tooltip(
                message: tooltip ?? "",
                child: Image.network(logoUrl, fit: BoxFit.contain),
              ),
      ),
    );
  }

  Widget _providerSection({
    required String heading,
    required List<dynamic> providersList,
    required String? link,
  }) {
    if (providersList.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: providersList.map((p) {
              final logo = p["logo_url"] as String?;
              final name = p["provider_name"] as String? ?? "";
              return _logoPill(
                logo,
                tooltip: name,
                onTap: () {
                  if (link != null) _openLink(link);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading || showData == null || trackedShow == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = showData!["name"] as String? ?? trackedShow!.title;
    final overview = showData!["overview"] as String? ?? "";
    final flatrate = (providers["flatrate"] as List<dynamic>? ?? []);
    final rent = (providers["rent"] as List<dynamic>? ?? []);
    final buy = (providers["buy"] as List<dynamic>? ?? []);
    final providerLink = providers["link"] as String?;

    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = (screenWidth * 0.4).clamp(120.0, 200.0);
    final posterHeight = posterWidth * 1.5;

    final totalEpisodes = trackedShow!.seasons.fold<int>(
      0,
      (s, x) => s + x.episodes.length,
    );
    final watchedEpisodes = trackedShow!.seasons.fold<int>(
      0,
      (s, x) => s + x.episodes.where((e) => e.watched).length,
    );
    final progress = totalEpisodes == 0 ? 0.0 : watchedEpisodes / totalEpisodes;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (trackedShow!.posterUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  trackedShow!.posterUrl!,
                  width: posterWidth,
                  height: posterHeight,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            if (totalEpisodes > 0)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(progress * 100).toStringAsFixed(0)}% watched ($watchedEpisodes / $totalEpisodes episodes)",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (overview.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(overview, textAlign: TextAlign.left),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Where to Watch ${widget.region}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _providerSection(
              heading: "Subscription:",
              providersList: flatrate,
              link: providerLink,
            ),
            _providerSection(
              heading: "Rent/Buy:",
              providersList: [...rent, ...buy],
              link: providerLink,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: "Mark Entire Show as Watched",
                  onPressed: _toggleEntireShowWatched,
                  icon: Icon(
                    trackedShow!.allWatched
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: trackedShow!.isWatchlisted
                      ? "Remove from Watchlist"
                      : "Add to Watchlist",
                  onPressed: _toggleWatchlist,
                  icon: Icon(
                    trackedShow!.isWatchlisted
                        ? Icons.bookmark
                        : Icons.bookmark_add_outlined,
                    size: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: trackedShow!.seasons.map((season) {
                final allWatched = season.episodes.every((e) => e.watched);
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Row(
                    children: [
                      Expanded(child: Text("Season ${season.number}")),
                      Checkbox(
                        value: allWatched,
                        onChanged: (val) {
                          setState(() {
                            for (final ep in season.episodes) {
                              ep.watched = val ?? false;
                            }
                            if (trackedShow!.allWatched) {
                              trackedShow!.isWatchlisted = false;
                            }
                          });
                          widget.onTrackedShowsChanged();
                        },
                      ),
                    ],
                  ),
                  children: season.episodes.map((ep) {
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        "Ep ${ep.number}. ${ep.title}",
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: ep.watched,
                      onChanged: (val) {
                        setState(() {
                          ep.watched = val ?? false;
                          if (trackedShow!.allWatched) {
                            trackedShow!.isWatchlisted = false;
                          }
                        });
                        widget.onTrackedShowsChanged();
                      },
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
