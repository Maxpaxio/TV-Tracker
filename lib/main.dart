// lib/main.dart
import 'package:flutter/material.dart';
import 'models/show_models.dart';
import 'services/storage.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final trackedShows = await Storage.loadShows();
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TV Tracker',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1C1C1C),
        cardColor: const Color(0xFF2A2A2A),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2A2A2A)),
      ),
      home: HomePage(
        apiKey: "6f8c0bbf88560ad26d47fcfa5f12cdc4", // TMDB key
        region: "SE", // region code
        trackedShows: trackedShows,
        saveShows: saveShows,
      ),
    );
  }
}
