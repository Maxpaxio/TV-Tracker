// lib/widgets/search_overlay.dart
import 'package:flutter/material.dart';
import '../models/show_models.dart';

/// Floating search results overlay that *overlaps* the home content.
class SearchOverlay extends StatelessWidget {
  final List<dynamic> results; // TMDB search raw results
  final List<Show> tracked; // current tracked shows
  final void Function(int tvId) onTapItem;
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickWatchlist;
  final VoidCallback onClose;

  const SearchOverlay({
    super.key,
    required this.results,
    required this.tracked,
    required this.onTapItem,
    required this.onQuickWatchlist,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Positioned.fill(
      child: Stack(
        children: [
          // Dim backdrop
          GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          // Results card
          Positioned(
            left: 12,
            right: 12,
            top: kToolbarHeight + topPadding + 8,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: _ResultList(
                  results: results,
                  tracked: tracked,
                  onTapItem: onTapItem,
                  onQuickWatchlist: onQuickWatchlist,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  final List<dynamic> results;
  final List<Show> tracked;
  final void Function(int tvId) onTapItem;
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickWatchlist;

  const _ResultList({
    required this.results,
    required this.tracked,
    required this.onTapItem,
    required this.onQuickWatchlist,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = results[i] as Map<String, dynamic>;
        final int tvId = (item['id'] as num).toInt();
        final String name = item['name'] ?? 'Unknown';
        final String? posterPath = item['poster_path'];
        final String? firstAir = item['first_air_date'];

        final status = _statusFor(tvId);

        return ListTile(
          leading: posterPath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    'https://image.tmdb.org/t/p/w92$posterPath',
                    width: 46,
                    height: 69,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.tv),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(firstAir != null ? 'First aired: $firstAir' : '—'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusChip(status),
              if (status == _ShowStatus.notAdded) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Add to Watchlist',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () async {
                    await onQuickWatchlist(tvId, name, posterPath);
                  },
                ),
              ],
            ],
          ),
          onTap: () => onTapItem(tvId),
        );
      },
    );
  }

  /// Determine status for a TMDB id based on current tracked list.
  _ShowStatus _statusFor(int tmdbId) {
    final s = tracked.firstWhere(
      (e) => e.tmdbId == tmdbId,
      orElse: () => Show.empty(),
    );
    if (s.tmdbId == -1) return _ShowStatus.notAdded;
    if (s.isWatchlisted) return _ShowStatus.watchlist;
    if (s.allWatched) return _ShowStatus.completed;
    if (s.anyWatched) return _ShowStatus.ongoing;
    return _ShowStatus.notAdded;
  }
}

enum _ShowStatus { notAdded, watchlist, ongoing, completed }

class _StatusChip extends StatelessWidget {
  final _ShowStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    late final IconData icon;

    switch (status) {
      case _ShowStatus.notAdded:
        color = Colors.grey;
        label = 'Not added';
        icon = Icons.add;
        break;
      case _ShowStatus.watchlist:
        color = Colors.amber;
        label = 'Watchlist';
        icon = Icons.bookmark;
        break;
      case _ShowStatus.ongoing:
        color = Colors.blue;
        label = 'Ongoing';
        icon = Icons.timelapse;
        break;
      case _ShowStatus.completed:
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
