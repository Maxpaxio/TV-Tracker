import 'package:flutter/material.dart';
import '../services/tmdb_api.dart';
import '../models/show_models.dart';
import 'show_detail_page.dart';

class PersonPage extends StatefulWidget {
  final int personId;
  final String apiKey;
  final String region;

  // Needed to open ShowDetailPage properly:
  final List<Show> trackedShows;
  final Future<void> Function() onTrackedShowsChanged;

  const PersonPage({
    super.key,
    required this.personId,
    required this.apiKey,
    required this.region,
    required this.trackedShows,
    required this.onTrackedShowsChanged,
  });

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  late TmdbApi api;
  Map<String, dynamic>? person;
  List<Map<String, String?>> credits = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = TmdbApi(widget.apiKey, region: widget.region);
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await api.getPerson(widget.personId);
      final cc = await api.getPersonCombinedCredits(widget.personId);
      final list = api.extractCreditsList(cc);

      setState(() {
        person = p;
        credits = list;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  void _openShowDetail(int tvId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShowDetailPage(
          showId: tvId,
          apiKey: widget.apiKey,
          region: widget.region,
          trackedShows: widget.trackedShows,
          onTrackedShowsChanged: widget.onTrackedShowsChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (person?['name'] as String?) ?? 'Person';
    final profile = (person != null) ? api.personProfileUrl(person!) : null;
    final knownFor = (person?['known_for_department'] as String?) ?? '';
    final place = (person?['place_of_birth'] as String?) ?? '';
    final birthday = (person?['birthday'] as String?) ?? '';
    final deathday = (person?['deathday'] as String?) ?? '';

    final tvCredits = credits
        .where((c) => (c['media_type'] ?? '') == 'tv')
        .toList();
    final movieCredits = credits
        .where((c) => (c['media_type'] ?? '') == 'movie')
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(name), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: profile != null
                          ? Image.network(
                              profile,
                              width: 120,
                              height: 160,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 120,
                              height: 160,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (knownFor.isNotEmpty)
                            Text(
                              'Department: $knownFor',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (birthday.isNotEmpty)
                            Text(
                              'Born: $birthday',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (deathday.isNotEmpty)
                            Text(
                              'Died: $deathday',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          if (place.isNotEmpty)
                            Text(
                              'From: $place',
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // TV Shows row (tappable)
                if (tvCredits.isNotEmpty) ...[
                  const Text(
                    'TV Shows',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _CreditsRow(
                    items: tvCredits,
                    onTap: (item) {
                      final idStr = item['id'];
                      final id = int.tryParse(idStr ?? '');
                      if (id != null) _openShowDetail(id);
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Films row (non-tappable for now)
                if (movieCredits.isNotEmpty) ...[
                  const Text(
                    'Films',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _CreditsRow(items: movieCredits),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _CreditsRow extends StatelessWidget {
  final List<Map<String, String?>> items;
  final void Function(Map<String, String?> item)? onTap;

  const _CreditsRow({required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Height tuned to avoid bottom overflow on compact screens.
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = items[i];
          final poster = c['poster'];
          final title = c['title'] ?? '';
          final year = c['year'] ?? '';
          final chara = c['character'] ?? '';

          final card = SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster (140 high to prevent overflow)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: poster != null
                      ? Image.network(
                          poster,
                          width: 110,
                          height: 140,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 110,
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
                const SizedBox(height: 4),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (year.isNotEmpty)
                  Text(
                    year,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (chara.isNotEmpty)
                  Text(
                    chara,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );

          return (onTap == null)
              ? card
              : InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTap!(c),
                  child: card,
                );
        },
      ),
    );
  }
}
