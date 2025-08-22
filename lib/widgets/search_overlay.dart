import 'package:flutter/material.dart';
import '../models/show_models.dart';

class SearchOverlay extends StatelessWidget {
  final List<dynamic> results;
  final List<Show> tracked;
  final void Function(int tvId) onTapItem;

  // Quick actions
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickWatchlist;
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickComplete;
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickMoveToWatchlist;
  final Future<void> Function(int tvId) onQuickRemove;

  final VoidCallback onClose;

  final double overlayTop;
  final double overlapPx;

  const SearchOverlay({
    super.key,
    required this.results,
    required this.tracked,
    required this.onTapItem,
    required this.onQuickWatchlist,
    required this.onQuickComplete,
    required this.onQuickMoveToWatchlist,
    required this.onQuickRemove,
    required this.onClose,
    required this.overlayTop,
    this.overlapPx = 0,
  });

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final maxHeight = screenH * 0.6;
    final double cardTop = (overlayTop - overlapPx).clamp(0, double.infinity);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: overlayTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: cardTop,
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.only(top: overlapPx),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: _ResultList(
                    results: results,
                    tracked: tracked,
                    onTapItem: onTapItem,
                    onQuickWatchlist: onQuickWatchlist,
                    onQuickComplete: onQuickComplete,
                    onQuickMoveToWatchlist: onQuickMoveToWatchlist,
                    onQuickRemove: onQuickRemove,
                  ),
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
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickComplete;
  final Future<void> Function(int tvId, String title, String? posterPath)
  onQuickMoveToWatchlist;
  final Future<void> Function(int tvId) onQuickRemove;

  const _ResultList({
    required this.results,
    required this.tracked,
    required this.onTapItem,
    required this.onQuickWatchlist,
    required this.onQuickComplete,
    required this.onQuickMoveToWatchlist,
    required this.onQuickRemove,
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
          trailing: _StatusChip(
            status: status,
            onTapOpenMenu: () => _showMenuForStatus(
              context,
              status: status,
              tvId: tvId,
              title: name,
              posterPath: posterPath,
            ),
          ),
          onTap: () => onTapItem(tvId),
        );
      },
    );
  }

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

  void _showMenuForStatus(
    BuildContext context, {
    required _ShowStatus status,
    required int tvId,
    required String title,
    required String? posterPath,
  }) {
    final items = <_MenuAction>[];

    switch (status) {
      case _ShowStatus.notAdded:
        items.addAll([
          _MenuAction(
            icon: Icons.bookmark_add_outlined,
            label: 'Add to Watchlist',
            run: () => onQuickWatchlist(tvId, title, posterPath),
          ),
          _MenuAction(
            icon: Icons.check_circle_outlined,
            label: 'Mark as Completed',
            run: () => onQuickComplete(tvId, title, posterPath),
          ),
        ]);
        break;
      case _ShowStatus.watchlist:
        items.addAll([
          _MenuAction(
            icon: Icons.check_circle_outlined,
            label: 'Mark as Completed',
            run: () => onQuickComplete(tvId, title, posterPath),
          ),
          _MenuAction(
            icon: Icons.delete_outline,
            label: 'Remove from Library',
            run: () => onQuickRemove(tvId),
          ),
        ]);
        break;
      case _ShowStatus.completed:
        items.addAll([
          _MenuAction(
            icon: Icons.bookmark_add_outlined,
            label: 'Move to Watchlist',
            run: () => onQuickMoveToWatchlist(tvId, title, posterPath),
          ),
          _MenuAction(
            icon: Icons.delete_outline,
            label: 'Remove from Library',
            run: () => onQuickRemove(tvId),
          ),
        ]);
        break;
      case _ShowStatus.ongoing:
        items.addAll([
          _MenuAction(
            icon: Icons.check_circle_outlined,
            label: 'Mark as Completed',
            run: () => onQuickComplete(tvId, title, posterPath),
          ),
          _MenuAction(
            icon: Icons.bookmark_add_outlined,
            label: 'Move to Watchlist',
            run: () => onQuickMoveToWatchlist(tvId, title, posterPath),
          ),
          _MenuAction(
            icon: Icons.delete_outline,
            label: 'Remove from Library',
            run: () => onQuickRemove(tvId),
          ),
        ]);
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((a) {
              return ListTile(
                leading: Icon(a.icon),
                title: Text(a.label),
                onTap: () async {
                  Navigator.pop(context);
                  await a.run();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

enum _ShowStatus { notAdded, watchlist, ongoing, completed }

class _MenuAction {
  final IconData icon;
  final String label;
  final Future<void> Function() run;
  _MenuAction({required this.icon, required this.label, required this.run});
}

class _StatusChip extends StatelessWidget {
  final _ShowStatus status;
  final VoidCallback onTapOpenMenu;

  const _StatusChip({required this.status, required this.onTapOpenMenu});

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

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
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

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTapOpenMenu,
      child: chip,
    );
  }
}
