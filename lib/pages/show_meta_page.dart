import 'package:flutter/material.dart';
import '../services/tmdb_api.dart';
import 'person_page.dart';
import '../models/show_models.dart';

class ShowMetaPage extends StatefulWidget {
  final int showId;
  final String apiKey;
  final String region;

  // Pass-through for opening Person → Show detail
  final List<Show> trackedShows;
  final Future<void> Function() onTrackedShowsChanged;

  const ShowMetaPage({
    super.key,
    required this.showId,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  State<ShowMetaPage> createState() => _ShowMetaPageState();
}

class _ShowMetaPageState extends State<ShowMetaPage> {
  late TmdbApi api;
  Map<String, dynamic>? detail;
  List<Map<String, dynamic>> cast = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = TmdbApi(widget.apiKey, region: widget.region);
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await api.getShowDetail(widget.showId);
      final credits = await api.getTvCredits(widget.showId);
      final castList = api.extractTopCast(credits, limit: 10);
      setState(() {
        detail = d;
        cast = castList;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final creators = d != null ? api.extractCreators(d) : const <String>[];
    final status = d != null ? api.extractStatus(d) : null;
    final rating = d != null ? api.extractVoteAverage(d) : null;
    final companies = d != null
        ? api.extractProductionCompanies(d)
        : const <Map<String, String?>>[];
    final genres = d != null ? api.extractGenres(d) : const <String>[];
    final runtimes = d != null ? api.extractEpisodeRunTimes(d) : const <int>[];
    final firstAir = d != null ? api.extractFirstAirDate(d) : null;
    final lastAir = d != null ? api.extractLastAirDate(d) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('More info'), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rating != null) ...[
                  const Text(
                    'Rating',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text('${rating.toStringAsFixed(1)} / 10'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                if (genres.isNotEmpty) ...[
                  const Text(
                    'Genres',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.map((g) => Chip(label: Text(g))).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                if (runtimes.isNotEmpty) ...[
                  const Text(
                    'Episode Runtime',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    runtimes.length == 1
                        ? '${runtimes.first} min'
                        : '${runtimes.join(', ')} min',
                  ),
                  const SizedBox(height: 16),
                ],

                if (firstAir != null || lastAir != null) ...[
                  const Text(
                    'Air Dates',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (firstAir != null) Text('First air date: $firstAir'),
                  if (lastAir != null) Text('Last air date: $lastAir'),
                  const SizedBox(height: 16),
                ],

                if (creators.isNotEmpty) ...[
                  const Text(
                    'Creator(s)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: creators
                        .map((c) => Chip(label: Text(c)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                if (companies.isNotEmpty) ...[
                  const Text(
                    'Production Companies',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: companies.map((pc) {
                      final name = pc['name'] ?? '';
                      final logo = pc['logo'];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: logo != null
                                ? Image.network(logo, fit: BoxFit.contain)
                                : const Icon(Icons.business),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 120,
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  'Top Cast',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 8),
                    itemCount: cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final c = cast[i];
                      final photo = c['profileUrl'] as String?;
                      final name = (c['name'] ?? '') as String;
                      final role = (c['character'] ?? '') as String;
                      final id = (c['id'] as int?) ?? -1;

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: id <= 0
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PersonPage(
                                      personId: id,
                                      apiKey: widget.apiKey,
                                      region: widget.region,
                                      trackedShows: widget.trackedShows,
                                      onTrackedShowsChanged:
                                          widget.onTrackedShowsChanged,
                                    ),
                                  ),
                                );
                              },
                        child: SizedBox(
                          width: 110,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: Colors.white10,
                                backgroundImage: (photo != null)
                                    ? NetworkImage(photo)
                                    : null,
                                child: (photo == null)
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                role,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
