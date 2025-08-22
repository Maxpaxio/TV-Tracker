// lib/pages/all_grid_page.dart
import 'package:flutter/material.dart';
import '../models/show_models.dart';

enum GridSort { alphabetical, recentlyAdded, topRated, releaseDate }

/// Provider filter descriptor (logo chip in the toolbar)
class ProviderFilter {
  final String
  name; // canonical name, e.g. "Netflix", "Max", "Not on streaming"
  final String? logoUrl; // null => show TV-off icon
  const ProviderFilter(this.name, this.logoUrl);
}

class AllGridPage extends StatefulWidget {
  final String title;
  final List<Show> shows;
  final bool showProgress; // true for Ongoing grid (no badges, show progress)
  final void Function(Show) onTapPoster;

  const AllGridPage({
    super.key,
    required this.title,
    required this.shows,
    required this.onTapPoster,
    this.showProgress = false,
  });

  @override
  State<AllGridPage> createState() => _AllGridPageState();
}

class _AllGridPageState extends State<AllGridPage> {
  late List<Show> _base; // original list, order defines "recently added"
  late Map<int, int> _originalIndex; // tmdbId -> index
  GridSort _sort = GridSort.recentlyAdded;

  // Selected provider names (multi-select)
  final Set<String> _selectedProviders = {};
  late final List<ProviderFilter> _filters;

  @override
  void initState() {
    super.initState();
    _base = List<Show>.from(widget.shows);
    _originalIndex = {
      for (int i = 0; i < _base.length; i++) _base[i].tmdbId: i,
    };
    _filters = _collectProviderFilters(_base);
  }

  // ---------- Provider name normalization ----------

  static const Set<String> _knownProviders = {
    'Netflix',
    'Max',
    'Disney+',
    'Prime Video',
    'Apple TV+',
    'Hulu',
    'Paramount+',
    'Peacock',
    'Starz',
    'Showtime',
  };

  String _canonicalizeName(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('netflix')) return 'Netflix';
    if (n == 'max' || n.contains('hbo')) return 'Max'; // HBO / HBO Max -> Max
    if (n.contains('disney')) return 'Disney+';
    if (n.contains('prime') || n.contains('amazon')) return 'Prime Video';
    if (n.contains('apple')) return 'Apple TV+';
    if (n.contains('paramount')) return 'Paramount+';
    if (n.contains('peacock')) return 'Peacock';
    if (n.contains('hulu')) return 'Hulu';
    if (n.contains('starz')) return 'Starz';
    if (n.contains('showtime')) return 'Showtime';
    return name; // leave as-is (will be ignored if not recognized)
  }

  /// If your Show has `List<String> subscriptionProviders`, use that.
  /// Otherwise infer from logo URLs (supports placeholders & common strings).
  Set<String> _namesForShow(Show s) {
    final names = <String>{};

    // Prefer explicit provider names if present on the model:
    try {
      final dyn = (s as dynamic).subscriptionProviders;
      if (dyn is List) {
        for (final p in dyn) {
          if (p is String) {
            final canon = _canonicalizeName(p);
            if (_knownProviders.contains(canon)) names.add(canon);
          }
        }
      }
    } catch (_) {
      // ignore
    }

    // Fall back to inferring from logo URLs
    if (names.isEmpty && s.subscriptionLogos.isNotEmpty) {
      for (final url in s.subscriptionLogos) {
        final name = _providerNameFromUrl(url);
        if (_knownProviders.contains(name)) names.add(name);
      }
    }

    // If nothing recognized and there are no logos, it counts as "Not on streaming"
    if (names.isEmpty && s.subscriptionLogos.isEmpty) {
      names.add('Not on streaming');
    }

    return names;
  }

  /// Map a logo URL (or placeholder) to a known provider name.
  String _providerNameFromUrl(String url) {
    final u = url.toLowerCase();

    // Dev placeholders: https://via.placeholder.com/...&text=N/D/P/A/M/H...
    final match = RegExp(r'[?&]text=([a-z])').firstMatch(u);
    if (u.contains('via.placeholder.com') && match != null) {
      switch (match.group(1)) {
        case 'n':
          return 'Netflix';
        case 'd':
          return 'Disney+';
        case 'p':
          return 'Prime Video';
        case 'a':
          return 'Apple TV+';
        case 'm':
        case 'h': // allow 'h' for HBO/Max placeholder
          return 'Max';
      }
    }

    if (u.contains('netflix')) return 'Netflix';
    if (u.contains('disney')) return 'Disney+';
    if (u.contains('prime') || u.contains('amazon')) return 'Prime Video';
    if (u.contains('apple')) return 'Apple TV+';
    if (u.contains('paramount')) return 'Paramount+';
    if (u.contains('peacock')) return 'Peacock';
    if (u.contains('hulu')) return 'Hulu';
    if (u.contains('starz')) return 'Starz';
    if (u.contains('showtime')) return 'Showtime';
    if (u.contains('hbomax') || u.contains('hbo') || u.contains('/max')) {
      return 'Max';
    }

    // Unknown → don’t surface a filter for it
    return '';
  }

  // Build the list of filter chips (logos) that we actually recognize.
  List<ProviderFilter> _collectProviderFilters(List<Show> shows) {
    final Map<String, String?> rep =
        {}; // name -> example logo URL (null => TV-off icon)
    bool sawNotOnStreaming = false;

    for (final s in shows) {
      final names = _namesForShow(s);
      for (final name in names) {
        if (name == 'Not on streaming') {
          sawNotOnStreaming = true;
          continue;
        }

        // Find first usable logo for that provider, if any
        if (!rep.containsKey(name)) {
          String? logo;
          for (final url in s.subscriptionLogos) {
            final mapped = _providerNameFromUrl(url);
            if (mapped == name) {
              logo = url;
              break;
            }
          }
          rep[name] = logo; // can be null if no recognizable logo URL
        }
      }
    }

    final out = <ProviderFilter>[];
    final ordered = rep.keys.toList()..sort();
    for (final name in ordered) {
      out.add(ProviderFilter(name, rep[name]));
    }
    if (sawNotOnStreaming) {
      out.add(const ProviderFilter('Not on streaming', null));
    }
    return out;
  }

  bool _matchesProviderFilter(Show s) {
    if (_selectedProviders.isEmpty) return true;
    final names = _namesForShow(s);
    return names.any(_selectedProviders.contains);
  }

  // ---------- Sorting helpers (safe against missing fields) ----------

  double? _ratingOf(Show s) {
    try {
      final d = (s as dynamic).voteAverage ?? (s as dynamic).rating;
      if (d is num) return d.toDouble();
    } catch (_) {}
    return null;
  }

  DateTime? _releaseDateOf(Show s) {
    try {
      final raw = (s as dynamic).firstAirDate ?? (s as dynamic).releaseDate;
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw) ?? DateTime.tryParse('$raw-01');
      }
    } catch (_) {}
    return null;
  }

  List<Show> _buildView() {
    // Filter
    var list = _base.where(_matchesProviderFilter).toList();

    // Sort
    switch (_sort) {
      case GridSort.alphabetical:
        list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case GridSort.recentlyAdded:
        list.sort(
          (a, b) => (_originalIndex[b.tmdbId] ?? 0).compareTo(
            _originalIndex[a.tmdbId] ?? 0,
          ),
        );
        break;
      case GridSort.topRated:
        list.sort((a, b) {
          final ar = _ratingOf(a) ?? -1;
          final br = _ratingOf(b) ?? -1;
          final cmp = br.compareTo(ar);
          return (cmp != 0) ? cmp : a.title.compareTo(b.title);
        });
        break;
      case GridSort.releaseDate:
        list.sort((a, b) {
          final ad =
              _releaseDateOf(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd =
              _releaseDateOf(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final cmp = bd.compareTo(ad);
          return (cmp != 0) ? cmp : a.title.compareTo(b.title);
        });
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final shows = _buildView();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<GridSort>(
            initialValue: _sort,
            onSelected: (val) => setState(() => _sort = val),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: GridSort.alphabetical,
                child: Text('Alphabetical'),
              ),
              PopupMenuItem(
                value: GridSort.recentlyAdded,
                child: Text('Recently added'),
              ),
              PopupMenuItem(value: GridSort.topRated, child: Text('Top rated')),
              PopupMenuItem(
                value: GridSort.releaseDate,
                child: Text('Release date'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // Logo filter row (known providers + "Not on streaming" TV-off)
          if (_filters.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final selected = _selectedProviders.contains(f.name);
                  return _LogoFilterBadge(
                    tooltip: f.name,
                    selected: selected,
                    logoUrl: f.logoUrl,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedProviders.remove(f.name);
                        } else {
                          _selectedProviders.add(f.name);
                        }
                      });
                    },
                  );
                },
              ),
            ),

          // Grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = 110.0; // ~80 poster + margins/title
                final crossAxisCount = (constraints.maxWidth / tileWidth)
                    .floor()
                    .clamp(3, 12);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: widget.showProgress
                        ? (80 / 156)
                        : (80 / 140),
                  ),
                  itemCount: shows.length,
                  itemBuilder: (_, i) {
                    final s = shows[i];
                    return GestureDetector(
                      onTap: () => widget.onTapPoster(s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Poster + overlays
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: s.posterUrl != null
                                    ? Image.network(
                                        s.posterUrl!,
                                        width: 80,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 80,
                                        height: 120,
                                        alignment: Alignment.center,
                                        color: Colors.white10,
                                        child: const Icon(Icons.tv),
                                      ),
                              ),

                              // provider logos (2x2 @ 18px)
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
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: s.subscriptionLogos.take(4).map(
                                        (logo) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                        },
                                      ).toList(),
                                    ),
                                  ),
                                ),

                              // badges: show only when NOT an ongoing grid
                              if (!widget.showProgress)
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
                          Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (widget.showProgress &&
                              s.anyWatched &&
                              !s.allWatched) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: s.progress,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular logo badge that toggles selection.
/// If [logoUrl] is null, show TV-off icon (for "Not on streaming").
class _LogoFilterBadge extends StatelessWidget {
  final String? logoUrl;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _LogoFilterBadge({
    required this.logoUrl,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.amber : Colors.white24;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? Colors.white10 : Colors.black26,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: (logoUrl != null && logoUrl!.isNotEmpty)
              ? Image.network(logoUrl!, fit: BoxFit.contain)
              : const Icon(Icons.tv_off_outlined), // TV with a slash
        ),
      ),
    );
  }
}
