import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/show_models.dart';
import '../services/tmdb_api.dart';
import 'show_detail_page.dart';
import 'all_grid_page.dart';
import '../widgets/search_overlay.dart';

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

  // Search state
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  List<dynamic> _searchResults = [];
  bool _searchLoading = false;
  double? _overlayTopLocal;

  @override
  void initState() {
    super.initState();
    trackedShows = widget.trackedShows;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeOverlayTop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeOverlayTop());
  }

  void _recomputeOverlayTop() {
    final searchBox =
        _searchKey.currentContext?.findRenderObject() as RenderBox?;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (searchBox == null || stackBox == null) return;

    final searchTopGlobal = searchBox.localToGlobal(Offset.zero);
    final searchBottomGlobal = Offset(
      searchTopGlobal.dx,
      searchTopGlobal.dy + searchBox.size.height,
    );

    final bottomLocal = stackBox.globalToLocal(searchBottomGlobal);
    setState(() => _overlayTopLocal = bottomLocal.dy);
  }

  Future<void> _persist() async {
    await widget.saveShows();
    if (mounted) setState(() {});
  }

  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    try {
      setState(() => _searchLoading = true);
      final api = TmdbApi(widget.apiKey, region: widget.region);
      final res = await api.searchShows(q);
      if (!mounted) return;
      setState(() {
        _searchResults = res;
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchLoading = false);
      if (kDebugMode) debugPrint('Search failed: $e');
    }
  }

  void _openDetailById(int tvId) {
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

  int _indexOfShow(int tmdbId) =>
      trackedShows.indexWhere((s) => s.tmdbId == tmdbId);

  void _replaceShowAt(int idx, Show newShow) {
    trackedShows = List<Show>.from(trackedShows)..[idx] = newShow;
  }

  void _upsertShow(Show newShow) {
    final idx = _indexOfShow(newShow.tmdbId);
    if (idx >= 0) {
      _replaceShowAt(idx, newShow);
    } else {
      trackedShows = List<Show>.from(trackedShows)..add(newShow);
    }
  }

  Show _ensureShowInLibrary({
    required int tvId,
    required String title,
    required String? posterPath,
  }) {
    final idx = _indexOfShow(tvId);
    if (idx >= 0) return trackedShows[idx];

    final posterUrl = (posterPath != null && posterPath.isNotEmpty)
        ? 'https://image.tmdb.org/t/p/w342$posterPath'
        : null;

    final created = Show(
      tmdbId: tvId,
      title: title,
      posterUrl: posterUrl,
      seasons: const [],
      isWatchlisted: false,
      subscriptionLogos: const [],
    );
    _upsertShow(created);
    return created;
  }

  Future<List<String>> _fetchProviderLogos(int tvId) async {
    try {
      final api = TmdbApi(widget.apiKey, region: widget.region);
      return await api.getWatchProvidersLogos(tvId);
    } catch (e) {
      if (kDebugMode) debugPrint('Provider logos fetch failed: $e');
      return const [];
    }
  }

  // ===== Quick actions (exclusive) ===========================================

  Future<void> _quickAddToWatchlistFromSearch(
    int tvId,
    String title,
    String? posterPath,
  ) async {
    final existing = _ensureShowInLibrary(
      tvId: tvId,
      title: title,
      posterPath: posterPath,
    );
    final idx = _indexOfShow(tvId);

    // Clear all episodes when moving to Watchlist
    final clearedSeasons = existing.seasons
        .map(
          (s) => s.copyWith(
            episodes: s.episodes
                .map((e) => e.copyWith(watched: false))
                .toList(),
          ),
        )
        .toList();

    final logos = await _fetchProviderLogos(tvId);

    final updated = existing.copyWith(
      isWatchlisted: true,
      seasons: clearedSeasons,
      subscriptionLogos: logos.isNotEmpty ? logos : existing.subscriptionLogos,
    );

    if (idx >= 0) {
      _replaceShowAt(idx, updated);
    } else {
      _upsertShow(updated);
    }
    await _persist();
  }

  Future<void> _quickMarkCompletedFromSearch(
    int tvId,
    String title,
    String? posterPath,
  ) async {
    final existing = _ensureShowInLibrary(
      tvId: tvId,
      title: title,
      posterPath: posterPath,
    );
    final idx = _indexOfShow(tvId);

    List<Season> newSeasons;
    if (existing.seasons.isEmpty) {
      newSeasons = [
        Season(
          number: 1,
          episodes: [Episode(number: 1, title: 'Episode 1', watched: true)],
        ),
      ];
    } else {
      newSeasons = existing.seasons
          .map(
            (s) => s.copyWith(
              episodes: s.episodes
                  .map((e) => e.copyWith(watched: true))
                  .toList(),
            ),
          )
          .toList();
    }

    final logos = await _fetchProviderLogos(tvId);

    final updated = existing.copyWith(
      isWatchlisted: false,
      seasons: newSeasons,
      subscriptionLogos: logos.isNotEmpty ? logos : existing.subscriptionLogos,
    );

    if (idx >= 0) {
      _replaceShowAt(idx, updated);
    } else {
      _upsertShow(updated);
    }
    await _persist();
  }

  Future<void> _quickMoveToWatchlistFromSearch(
    int tvId,
    String title,
    String? posterPath,
  ) async {
    await _quickAddToWatchlistFromSearch(tvId, title, posterPath);
  }

  Future<void> _quickRemoveFromLibrary(int tvId) async {
    trackedShows = List<Show>.from(trackedShows)
      ..removeWhere((s) => s.tmdbId == tvId);
    await _persist();
  }

  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // Exclusive buckets
    final watchlist = trackedShows.where((s) => s.isWatchlisted).toList();
    final completed = trackedShows
        .where((s) => !s.isWatchlisted && s.allWatched)
        .toList();
    final ongoing = trackedShows
        .where((s) => !s.isWatchlisted && s.anyWatched && !s.allWatched)
        .toList();

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Container(
            key: _searchKey,
            child: TextField(
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
                          setState(() {
                            _searchResults = [];
                            _searchLoading = false;
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => _doSearch(v),
              onSubmitted: _doSearch,
            ),
          ),
          const SizedBox(height: 12),

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
              onTapPoster: (s) => _openDetailById(s.tmdbId),
              showProgress: true,
              showBadges: false,
            ),

          const SizedBox(height: 16),

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
              onTapPoster: (s) => _openDetailById(s.tmdbId),
            ),

          const SizedBox(height: 16),

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
              onTapPoster: (s) => _openDetailById(s.tmdbId),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('TV Tracker'), centerTitle: true),
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            body,
            if (_searchLoading && _overlayTopLocal != null)
              Positioned(
                left: 12,
                right: 12,
                top: _overlayTopLocal! + 2,
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            if (_searchResults.isNotEmpty && _overlayTopLocal != null)
              SearchOverlay(
                results: _searchResults,
                tracked: trackedShows,
                onTapItem: (tvId) => _openDetailById(tvId),
                onQuickWatchlist: _quickAddToWatchlistFromSearch,
                onQuickComplete: _quickMarkCompletedFromSearch,
                onQuickMoveToWatchlist: _quickMoveToWatchlistFromSearch,
                onQuickRemove: _quickRemoveFromLibrary,
                onClose: () => setState(() => _searchResults = []),
                overlayTop: _overlayTopLocal!,
                overlapPx: 0,
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
    final progressH = showProgress ? (6.0 + 6.0) : 0.0;
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
                    if (s.subscriptionLogos.isNotEmpty)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: SizedBox(
                          width: 40,
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
                                    color: Colors.white.withValues(alpha: 0.24),
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
