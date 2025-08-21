// lib/services/tmdb_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/show_models.dart';

class TmdbApi {
  final String apiKey;
  final String region; // e.g. "SE"
  TmdbApi(this.apiKey, {this.region = "US"});

  static const _base = "https://api.themoviedb.org/3";

  Future<List<dynamic>> searchShows(String query) async {
    final url = Uri.parse(
      "$_base/search/tv?api_key=$apiKey&query=${Uri.encodeQueryComponent(query)}",
    );
    final r = await http.get(url);
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data["results"] as List<dynamic>? ?? []);
  }

  Future<Map<String, dynamic>?> getShowDetail(int tvId) async {
    final url = Uri.parse("$_base/tv/$tvId?api_key=$apiKey");
    final r = await http.get(url);
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Season>> buildSeasonsWithEpisodeTitles(
    int tvId,
    List<dynamic> seasonsJson,
  ) async {
    final out = <Season>[];
    for (final s in seasonsJson) {
      final sn = s["season_number"] ?? 0;
      if (sn == 0) continue;
      final d = await _getSeasonDetail(tvId, sn);
      final eps = (d?["episodes"] as List<dynamic>? ?? [])
          .map(
            (e) => Episode(
              number: e["episode_number"] ?? 0,
              title: e["name"] ?? "Episode ${e["episode_number"] ?? ""}",
            ),
          )
          .toList();
      out.add(Season(number: sn, episodes: eps));
    }
    return out;
  }

  Future<Map<String, dynamic>?> _getSeasonDetail(int tvId, int s) async {
    final url = Uri.parse("$_base/tv/$tvId/season/$s?api_key=$apiKey");
    final r = await http.get(url);
    if (r.statusCode != 200) return null;
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  String? providerLogoFromDetail(Map<String, dynamic> detail) {
    final networks = (detail["networks"] as List<dynamic>? ?? []);
    if (networks.isNotEmpty && networks.first["logo_path"] != null) {
      return "https://image.tmdb.org/t/p/w92${networks.first["logo_path"]}";
    }
    return null;
  }

  String? posterUrlSmallFromDetail(Map<String, dynamic> detail) {
    final p = detail["poster_path"];
    if (p == null) return null;
    return "https://image.tmdb.org/t/p/w185$p";
  }

  String? posterUrlLargeFromDetail(Map<String, dynamic> detail) {
    final p = detail["poster_path"];
    if (p == null) return null;
    return "https://image.tmdb.org/t/p/w342$p";
  }

  /// --- Watch Providers ---
  Future<Map<String, dynamic>> getWatchProviders(int tvId) async {
    final url = Uri.parse("$_base/tv/$tvId/watch/providers?api_key=$apiKey");
    final r = await http.get(url);
    if (r.statusCode != 200) return {};
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final byCountry = (data["results"] as Map<String, dynamic>? ?? {});
    final country = byCountry[region] as Map<String, dynamic>?;
    if (country == null) return {};
    List<Map<String, dynamic>> norm(List<dynamic>? arr) =>
        (arr ?? [])
            .cast<Map<String, dynamic>>()
            .map(
              (p) => {
                "provider_id": p["provider_id"],
                "provider_name": p["provider_name"],
                "logo_url": p["logo_path"] != null
                    ? "https://image.tmdb.org/t/p/w92${p["logo_path"]}"
                    : null,
                "display_priority": p["display_priority"] ?? 999,
              },
            )
            .toList()
          ..sort(
            (a, b) => (a["display_priority"] as int).compareTo(
              b["display_priority"] as int,
            ),
          );

    return {
      "link": country["link"],
      "flatrate": norm(country["flatrate"] as List<dynamic>?),
      "rent": norm(country["rent"] as List<dynamic>?),
      "buy": norm(country["buy"] as List<dynamic>?),
    };
  }

  /// Extract up to [max] flatrate logo URLs from a providers map.
  List<String> extractFlatrateLogos(
    Map<String, dynamic> providers, {
    int max = 4,
  }) {
    final flatrate = (providers["flatrate"] as List<dynamic>? ?? []);
    return flatrate
        .map((p) => p["logo_url"] as String?)
        .whereType<String>()
        .take(max)
        .toList();
  }
}
