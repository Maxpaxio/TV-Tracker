// lib/models/show_models.dart
import 'dart:convert';

class Episode {
  final int number;
  final String title;
  final bool watched;

  Episode({required this.number, required this.title, required this.watched});

  Episode copyWith({int? number, String? title, bool? watched}) {
    return Episode(
      number: number ?? this.number,
      title: title ?? this.title,
      watched: watched ?? this.watched,
    );
  }

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    number: (json['number'] as num).toInt(),
    title:
        json['title'] as String? ??
        'Episode ${(json['number'] as num).toInt()}',
    watched: json['watched'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'watched': watched,
  };
}

class Season {
  final int number;
  final List<Episode> episodes;

  Season({required this.number, required this.episodes});

  Season copyWith({int? number, List<Episode>? episodes}) {
    return Season(
      number: number ?? this.number,
      episodes: episodes ?? this.episodes,
    );
  }

  bool get anyWatched => episodes.any((e) => e.watched);
  bool get allWatched =>
      episodes.isNotEmpty && episodes.every((e) => e.watched);

  int get watchedCount => episodes.where((e) => e.watched).length;
  int get totalEpisodes => episodes.length;

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    number: (json['number'] as num).toInt(),
    episodes: ((json['episodes'] as List?) ?? const [])
        .map((e) => Episode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'number': number,
    'episodes': episodes.map((e) => e.toJson()).toList(),
  };
}

class Show {
  final int tmdbId;
  final String title;
  final String? posterUrl;
  final List<Season> seasons;
  final bool isWatchlisted;
  final List<String> subscriptionLogos;

  Show({
    required this.tmdbId,
    required this.title,
    required this.posterUrl,
    required this.seasons,
    required this.isWatchlisted,
    required this.subscriptionLogos,
  });

  Show copyWith({
    int? tmdbId,
    String? title,
    String? posterUrl,
    List<Season>? seasons,
    bool? isWatchlisted,
    List<String>? subscriptionLogos,
  }) {
    return Show(
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      seasons: seasons ?? this.seasons,
      isWatchlisted: isWatchlisted ?? this.isWatchlisted,
      subscriptionLogos: subscriptionLogos ?? this.subscriptionLogos,
    );
  }

  static Show empty() => Show(
    tmdbId: -1,
    title: '',
    posterUrl: null,
    seasons: const [],
    isWatchlisted: false,
    subscriptionLogos: const [],
  );

  bool get anyWatched => seasons.any((s) => s.anyWatched);
  bool get allWatched {
    final total = totalEpisodes;
    if (total == 0) return false;
    return watchedCount == total;
  }

  int get watchedCount => seasons.fold(0, (sum, s) => sum + s.watchedCount);
  int get totalEpisodes => seasons.fold(0, (sum, s) => sum + s.totalEpisodes);

  /// 0.0..1.0, or 0 if no episodes yet
  double get progress {
    final total = totalEpisodes;
    if (total == 0) return 0.0;
    return watchedCount / total;
  }

  factory Show.fromJson(Map<String, dynamic> json) => Show(
    tmdbId: (json['tmdbId'] as num).toInt(),
    title: json['title'] as String? ?? '',
    posterUrl: json['posterUrl'] as String?,
    seasons: ((json['seasons'] as List?) ?? const [])
        .map((s) => Season.fromJson(s as Map<String, dynamic>))
        .toList(),
    isWatchlisted: json['isWatchlisted'] as bool? ?? false,
    subscriptionLogos: ((json['subscriptionLogos'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'tmdbId': tmdbId,
    'title': title,
    'posterUrl': posterUrl,
    'seasons': seasons.map((s) => s.toJson()).toList(),
    'isWatchlisted': isWatchlisted,
    'subscriptionLogos': subscriptionLogos,
  };

  static List<Show> listFromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = json.decode(jsonStr) as List<dynamic>;
    return list.map((e) => Show.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJsonString(List<Show> shows) {
    final list = shows.map((s) => s.toJson()).toList();
    return json.encode(list);
  }
}
