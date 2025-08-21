// lib/pages/home_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/show_models.dart';
import '../services/tmdb_api.dart';
import 'show_detail_page.dart';
import 'all_grid_page.dart';
import '../widgets/search_overlay.dart'; // <-- overlay

class HomePage extends StatefulWidget {
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final Future<void> Function() saveShows;

  const HomePage({
    super.key,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.saveShows,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Show> trackedShows;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _searchLoading = false;

  @override
  void initState() {
    super.initState();
    trackedShows = widget.trackedShows;
  }

  Future<void> _persist() async {
    await widget.saveShows();
    if (mounted) setState(() {});
  }

  Future<void> _doSearch(String q) async {
    try {
      if (q.trim().isEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      setState(() => _searchLoading = true);
      final api = TmdbApi(widget.apiKey, region: widget.region);
      final res = await api.searchShows(q);
      if (!mounted) return;
      setState(() {
        _searchResults = res;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchLoading = false);
      if (kDebugMode) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Search failed')));
      }
    }
  }

  void _openDetailById(int tvId) {
    // IMPORTANT: do NOT clear search state here; we want it to still be there when you pop back.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShowDetailPage(
          showId: tvId,
          apiKey: widget.apiKey,
          region: widget.region,
          trackedShows: trackedShows,
          onTrackedShowsChanged: _persist,
        ),
      ),
    );
  }

  void _openDetailForShow(Show s) => _openDetailById(s.tmdbId);

  // Quick add to watchlist straight from search overlay
  Future<void> _quickAddToWatchlistFromSearch(
    int tvId,
    String title,
    String? posterPath,
  ) async {
    // find existing
    final idx = trackedShows.indexWhere((s) => s.tmdbId == tvId);
    if (idx >= 0) {
      final s = trackedShows[idx];
      if (!s.isWatchlisted) {
        s.isWatchlisted = true;
      }
    } else {
      // create a minimal Show; seasons empty is fine for watchlist
      final posterUrl = (posterPath != null && posterPath.isNotEmpty)
          ? 'https://image.tmdb.org/t/p/w342$posterPath'
          : null;

      trackedShows.add(
        Show(
          tmdbId: tvId,
          title: title,
          posterUrl: posterUrl,
          seasons: const [],
          isWatchlisted: true,
          subscriptionLogos: const [],
        ),
      );
    }
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = trackedShows.where((s) {
      try {
        return s.anyWatched && !s.allWatched;
      } catch (_) {
        return false;
      }
    }).toList();

    final completed = trackedShows.where((s) {
      try {
        return s.allWatched;
      } catch (_) {
        return false;
      }
    }).toList();

    final watchlist = trackedShows.where((s) {
      try {
        return s.isWatchlisted;
      } catch (_) {
        return false;
      }
    }).toList();

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 Search bar (results overlay; does not push sections)
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search TV shows…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) {
              setState(() {}); // toggle clear button
              _doSearch(v);
            },
            onSubmitted: _doSearch,
          ),
          if (_searchLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 8),

          // 🔧 Tiny debug counters
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'tracked=${trackedShows.length} • ongoing=${ongoing.length} • completed=${completed.length} • watchlist=${watchlist.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),

          // ===== Ongoing (horizontal row with progress bar; NO badges) =====
          SectionHeader(
            title: 'Ongoing (${ongoing.length})',
            onTap: () => _openAllGrid(
              context,
              title: 'All Ongoing',
              shows: ongoing,
              showProgress: true,
            ),
          ),
          if (ongoing.isEmpty)
            const EmptyHint(
              "No ongoing shows yet. Mark some episodes watched to see them here.",
            )
          else
            const SizedBox(height: 6),
          if (ongoing.isNotEmpty)
            HorizontalPosterRow(
              shows: ongoing.take(12).toList(),
              onTapPoster: _openDetailForShow,
              showProgress: true,
              showBadges: false,
            ),

          const SizedBox(height: 16),

          // ===== Completed =====
          SectionHeader(
            title: 'Completed (${completed.length})',
            onTap: () =>
                _openAllGrid(context, title: 'All Completed', shows: completed),
          ),
          if (completed.isEmpty)
            const EmptyHint(
              "Nothing completed yet. Finish all episodes of a show to move it here.",
            )
          else
            const SizedBox(height: 6),
          if (completed.isNotEmpty)
            HorizontalPosterRow(
              shows: completed.take(12).toList(),
              onTapPoster: _openDetailForShow,
            ),

          const SizedBox(height: 16),

          // ===== Watchlist =====
          SectionHeader(
            title: 'Watchlist (${watchlist.length})',
            onTap: () =>
                _openAllGrid(context, title: 'All Watchlist', shows: watchlist),
          ),
          if (watchlist.isEmpty)
            const EmptyHint("Add shows to your watchlist to see them here.")
          else
            const SizedBox(height: 6),
          if (watchlist.isNotEmpty)
            HorizontalPosterRow(
              shows: watchlist.take(12).toList(),
              onTapPoster: _openDetailForShow,
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            // Keep results when tapping title? Up to you; I won't clear them here.
          },
          child: const Text('TV Tracker'),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            body,

            // 🔎 Overlapping search overlay (stays in memory during navigation)
            if (_searchResults.isNotEmpty)
              SearchOverlay(
                results: _searchResults,
                tracked: trackedShows,
                onTapItem: (tvId) {
                  // Do NOT clear here – we want the overlay/results to be remembered.
                  _openDetailById(tvId);
                },
                onQuickWatchlist: (tvId, title, posterPath) async {
                  await _quickAddToWatchlistFromSearch(tvId, title, posterPath);
                },
                onClose: () {
                  setState(() {
                    _searchResults = [];
                    _searchCtrl.clear();
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openAllGrid(
    BuildContext context, {
    required String title,
    required List<Show> shows,
    bool showProgress = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllGridPage(
          title: title,
          shows: shows,
          showProgress: showProgress,
          onTapPoster: (s) => _openDetailById(s.tmdbId),
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

/// Single-row, horizontally scrollable posters (80x120)
/// - Top-left: subscription logos (2×2 @ 18px)
/// - Top-right: badges (bookmark, check) — can be disabled
/// - Optional progress bar below title when [showProgress] is true
class HorizontalPosterRow extends StatelessWidget {
  final List<Show> shows;
  final void Function(Show show) onTapPoster;
  final bool showProgress;
  final bool showBadges;

  const HorizontalPosterRow({
    super.key,
    required this.shows,
    required this.onTapPoster,
    this.showProgress = false,
    this.showBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    final posterH = 120.0;
    final titleH = 18.0;
    final gap = 6.0;
    final progressH = showProgress ? (6.0 + 6.0) : 0.0; // bar + gap
    final totalHeight = posterH + gap + titleH + progressH + 8.0;

    return SizedBox(
      height: totalHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        scrollDirection: Axis.horizontal,
        itemCount: shows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = shows[i];
          return SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    // Poster
                    GestureDetector(
                      onTap: () => onTapPoster(s),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: s.posterUrl != null
                            ? Image.network(
                                s.posterUrl!,
                                width: 80,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 120,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 120,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tv),
                              ),
                      ),
                    ),

                    // TOP-LEFT: subscription logos (2×2 grid, 18px)
                    if (s.subscriptionLogos.isNotEmpty)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: SizedBox(
                          width: 40, // 18 + 2 + 18 + 2
                          height: 40,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            children: s.subscriptionLogos.take(4).map((logo) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white24,
                                    width: 0.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(
                                  logo,
                                  fit: BoxFit.contain,
                                  width: 18,
                                  height: 18,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // TOP-RIGHT: badges (hidden for Ongoing)
                    if (showBadges)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          children: [
                            if (s.isWatchlisted)
                              const Icon(
                                Icons.bookmark,
                                size: 18,
                                color: Colors.amber,
                              ),
                            if (s.allWatched) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.greenAccent,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),

                // Progress bar (ongoing only)
                if (showProgress && s.anyWatched && !s.allWatched) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: s.progress),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Simple section header (title + chevron)
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const SectionHeader({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
