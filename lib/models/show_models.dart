// lib/models/show_models.dart

class Show {
  int tmdbId;
  String title;
  List<Season> seasons;
  String? posterUrl; // e.g., TMDB poster (w185)
  String? platformLogoUrl; // optional legacy single logo (e.g., network logo)
  bool isWatchlisted;
  List<String>
  subscriptionLogos; // TMDB "flatrate" provider logo URLs for homepage badges

  Show({
    required this.tmdbId,
    required this.title,
    required this.seasons,
    this.posterUrl,
    this.platformLogoUrl,
    this.isWatchlisted = false,
    List<String>? subscriptionLogos,
  }) : subscriptionLogos = subscriptionLogos ?? [];

  /// Any episode watched across all seasons?
  bool get anyWatched => seasons.any((s) => s.episodes.any((e) => e.watched));

  /// All episodes watched (and there is at least one episode in each season)?
  bool get allWatched =>
      seasons.isNotEmpty &&
      seasons.every(
        (s) => s.episodes.isNotEmpty && s.episodes.every((e) => e.watched),
      );

  /// 0.0–1.0 total watched progress across all episodes.
  double get progress {
    final total = seasons.fold<int>(0, (sum, s) => sum + s.episodes.length);
    if (total == 0) return 0.0;
    final watched = seasons.fold<int>(
      0,
      (sum, s) => sum + s.episodes.where((e) => e.watched).length,
    );
    return watched / total;
  }

  // in lib/models/show_models.dart (inside class Show)
  factory Show.empty() {
    return Show(
      tmdbId: -1,
      title: '',
      posterUrl: null,
      seasons: const [],
      isWatchlisted: false,
      subscriptionLogos: const [],
    );
  }

  factory Show.fromJson(Map<String, dynamic> json) => Show(
    tmdbId: (json['tmdbId'] as num).toInt(),
    title: json['title'] as String? ?? "",
    seasons: (json['seasons'] as List<dynamic>? ?? [])
        .map((s) => Season.fromJson(s as Map<String, dynamic>))
        .toList(),
    posterUrl: json['posterUrl'] as String?,
    platformLogoUrl: json['platformLogoUrl'] as String?,
    isWatchlisted: json['isWatchlisted'] as bool? ?? false,
    subscriptionLogos: (json['subscriptionLogos'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'tmdbId': tmdbId,
    'title': title,
    'seasons': seasons.map((s) => s.toJson()).toList(),
    'posterUrl': posterUrl,
    'platformLogoUrl': platformLogoUrl,
    'isWatchlisted': isWatchlisted,
    'subscriptionLogos': subscriptionLogos,
  };
}

class Season {
  int number;
  List<Episode> episodes;

  Season({required this.number, required this.episodes});

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    number: (json['number'] as num?)?.toInt() ?? 0,
    episodes: (json['episodes'] as List<dynamic>? ?? [])
        .map((e) => Episode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'episodes': episodes.map((e) => e.toJson()).toList(),
  };
}

class Episode {
  int number;
  String title;
  bool watched;

  Episode({required this.number, required this.title, this.watched = false});

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    number: (json['number'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? "",
    watched: json['watched'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'watched': watched,
  };
}
