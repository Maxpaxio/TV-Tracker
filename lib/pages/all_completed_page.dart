import 'package:flutter/material.dart';
import '../models/show_models.dart';
import 'show_detail_page.dart';

class AllCompletedPage extends StatelessWidget {
  final List<Show> shows;
  final String apiKey;
  final String region;
  final List<Show> trackedShows;
  final Future<void> Function() onTrackedShowsChanged;

  const AllCompletedPage({
    super.key,
    required this.shows,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  void _openDetail(BuildContext context, int tvId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShowDetailPage(
          showId: tvId,
          apiKey: apiKey,
          region: region,
          trackedShows: trackedShows,
          onTrackedShowsChanged: onTrackedShowsChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("All Completed Shows")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = 110.0;
          final crossAxisCount = (constraints.maxWidth / tileWidth)
              .floor()
              .clamp(3, 12);
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 80 / 140,
            ),
            itemCount: shows.length,
            itemBuilder: (_, i) {
              final s = shows[i];
              return GestureDetector(
                onTap: () => _openDetail(context, s.tmdbId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tv),
                                ),
                        ),
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
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.greenAccent,
                              ),
                            ],
                          ),
                        ),
                        if (s.subscriptionLogos.isNotEmpty)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Row(
                              children: s.subscriptionLogos.take(4).map((logo) {
                                return Container(
                                  width: 16,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 0.5,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    logo,
                                    fit: BoxFit.contain,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
