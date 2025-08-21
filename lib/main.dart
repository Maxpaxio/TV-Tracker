// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode
import 'models/show_models.dart';
import 'services/storage.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved shows
  var trackedShows = await Storage.loadShows();

  // Inject dummy data only in Debug builds AND only if storage is empty
  if (kDebugMode && trackedShows.isEmpty) {
    trackedShows = _generateDummyShows();
  }

  runApp(TvTrackerApp(trackedShows: trackedShows));
}

class TvTrackerApp extends StatefulWidget {
  final List<Show> trackedShows;

  const TvTrackerApp({super.key, required this.trackedShows});

  @override
  State<TvTrackerApp> createState() => _TvTrackerAppState();
}

class _TvTrackerAppState extends State<TvTrackerApp> {
  late List<Show> trackedShows;

  @override
  void initState() {
    super.initState();
    trackedShows = widget.trackedShows;
  }

  Future<void> saveShows() async {
    await Storage.saveShows(trackedShows);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1C1C1C), // dark gray
        cardColor: const Color(0xFF2A2A2A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2A2A2A),
          elevation: 0,
        ),
        dividerColor: Colors.white12,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: HomePage(
        apiKey: "6f8c0bbf88560ad26d47fcfa5f12cdc4", // your TMDB key
        region: "SE",
        trackedShows: trackedShows,
        saveShows: saveShows,
      ),
    );
  }
}

/// ---------- Dummy Data (Debug-only) ----------

List<Show> _generateDummyShows() {
  final List<Show> out = [];

  // Helper logos (PNG placeholders so they render everywhere)
  const nLogo = 'https://via.placeholder.com/32x32.png?text=N';
  const pLogo = 'https://via.placeholder.com/32x32.png?text=P';
  const dLogo = 'https://via.placeholder.com/32x32.png?text=D';
  const aLogo = 'https://via.placeholder.com/32x32.png?text=A';

  // Ongoing: some episodes watched but not all
  for (int i = 0; i < 10; i++) {
    out.add(
      Show(
        tmdbId: 1000 + i,
        title: "Ongoing Show $i",
        seasons: _makeSeasons(
          seasonCount: 2 + (i % 2),
          epsPerSeason: 8 + (i % 3),
          watchedPerSeason: (i % 5) + 1, // >0 but < total
        ),
        posterUrl:
            "https://via.placeholder.com/160x240.png?text=Ongoing+$i", // 80x120 scale x2
        isWatchlisted: i.isEven ? false : true,
        subscriptionLogos: [nLogo, pLogo, dLogo].take(1 + (i % 3)).toList(),
      ),
    );
  }

  // Completed: all episodes watched
  for (int i = 0; i < 10; i++) {
    final eps = 10 + (i % 3);
    out.add(
      Show(
        tmdbId: 2000 + i,
        title: "Completed Show $i",
        seasons: _makeSeasons(
          seasonCount: 2,
          epsPerSeason: eps,
          watchedPerSeason: eps, // all watched
        ),
        posterUrl: "https://via.placeholder.com/160x240.png?text=Completed+$i",
        isWatchlisted: false,
        subscriptionLogos: [aLogo, dLogo],
      ),
    );
  }

  // Watchlist: nothing watched, but flagged to watch
  for (int i = 0; i < 10; i++) {
    out.add(
      Show(
        tmdbId: 3000 + i,
        title: "Watchlist Show $i",
        seasons: _makeSeasons(
          seasonCount: 1 + (i % 2),
          epsPerSeason: 6 + (i % 4),
          watchedPerSeason: 0, // none watched
        ),
        posterUrl: "https://via.placeholder.com/160x240.png?text=Watchlist+$i",
        isWatchlisted: true,
        subscriptionLogos: [pLogo, nLogo],
      ),
    );
  }

  return out;
}

/// Build seasons/episodes with a given watched count per season
List<Season> _makeSeasons({
  required int seasonCount,
  required int epsPerSeason,
  required int watchedPerSeason,
}) {
  final List<Season> seasons = [];
  for (int s = 1; s <= seasonCount; s++) {
    final List<Episode> eps = [];
    for (int e = 1; e <= epsPerSeason; e++) {
      eps.add(
        Episode(number: e, title: "Episode $e", watched: e <= watchedPerSeason),
      );
    }
    seasons.add(Season(number: s, episodes: eps));
  }
  return seasons;
}
