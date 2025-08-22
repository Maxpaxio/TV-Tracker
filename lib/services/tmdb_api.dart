import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/show_models.dart';

class TmdbApi {
  final String apiKey;
  final String region; // e.g., "SE", "US", "GB"

  TmdbApi(this.apiKey, {required this.region});

  static const _base = 'https://api.themoviedb.org/3';
  static const _img = 'https://image.tmdb.org/t/p';

  Uri _u(String path, [Map<String, String>? q]) {
    final params = {'api_key': apiKey, if (q != null) ...q};
    return Uri.parse('$_base$path').replace(queryParameters: params);
  }

  static String? imageUrl(String size, String? path) {
    if (path == null || path.isEmpty) return null;
    return '$_img/$size$path';
  }
  // Put this inside class TmdbApi { ... }

  /// Convenience for older call sites: returns region-scoped SUBSCRIPTION logo URLs.
  /// Falls back to network logos from the show detail if none are available.
  Future<List<String>> getWatchProvidersLogos(int tvId) async {
    try {
      final raw = await getWatchProvidersRaw(tvId);
      final subsProviders = extractFlatrateProviders(raw, region);
      if (subsProviders.isNotEmpty) {
        return subsProviders.map((p) => p.logoUrl).toList();
      }
      // Fallback: use network logos from the show detail (not region-filtered)
      final detail = await getShowDetail(tvId);
      return providerLogoFromDetail(detail);
    } catch (_) {
      return const [];
    }
  }

  // -------- Search --------
  Future<List<dynamic>> searchShows(String query) async {
    final res = await http.get(
      _u('/search/tv', {
        'query': query,
        'include_adult': 'false',
        'language': 'en-US',
        'page': '1',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Search failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['results'] as List).cast<dynamic>();
  }

  // -------- Show / Seasons --------
  Future<Map<String, dynamic>> getShowDetail(int tvId) async {
    final res = await http.get(_u('/tv/$tvId', {'language': 'en-US'}));
    if (res.statusCode != 200) {
      throw Exception('TV details failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSeason(int tvId, int seasonNumber) async {
    final res = await http.get(
      _u('/tv/$tvId/season/$seasonNumber', {'language': 'en-US'}),
    );
    if (res.statusCode != 200) {
      throw Exception('Season $seasonNumber failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Season>> buildSeasonsWithEpisodeTitles(
    int tvId, {
    int? maxSeasons,
  }) async {
    final detail = await getShowDetail(tvId);
    final seasonsArr = (detail['seasons'] as List?) ?? const [];
    final seasonNumbers =
        seasonsArr
            .map(
              (s) => (s as Map<String, dynamic>)['season_number'] as int? ?? 0,
            )
            .where((n) => n > 0)
            .toList()
          ..sort();
    final take = maxSeasons != null
        ? seasonNumbers.take(maxSeasons).toList()
        : seasonNumbers;

    final result = <Season>[];
    for (final sn in take) {
      final sJson = await getSeason(tvId, sn);
      final epsJson = (sJson['episodes'] as List?) ?? const [];
      final eps = epsJson.map((e) {
        final me = e as Map<String, dynamic>;
        final epNum = (me['episode_number'] as num?)?.toInt() ?? 0;
        final epTitle = (me['name'] as String?)?.trim();
        return Episode(
          number: epNum,
          title: (epTitle == null || epTitle.isEmpty)
              ? 'Episode $epNum'
              : epTitle,
          watched: false,
        );
      }).toList();
      result.add(Season(number: sn, episodes: eps));
    }
    return result;
  }

  String? posterUrlSmallFromDetail(Map<String, dynamic> detail) {
    final posterPath = detail['poster_path'] as String?;
    return imageUrl('w342', posterPath);
  }

  String? backdropUrlFromDetail(
    Map<String, dynamic> detail, {
    String size = 'w780',
  }) {
    final path = detail['backdrop_path'] as String?;
    return imageUrl(size, path);
  }

  // -------- Watch providers (region-specific) --------

  Future<Map<String, dynamic>> getWatchProvidersRaw(int tvId) async {
    final res = await http.get(_u('/tv/$tvId/watch/providers'));
    if (res.statusCode != 200) {
      throw Exception('Watch providers failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Returns the region provider page (a TMDB/JustWatch link) like
  /// https://www.themoviedb.org/tv/{id}/watch?locale=SE
  String? extractRegionProviderPageLink(
    Map<String, dynamic> providersJson,
    String regionCode,
  ) {
    final results = (providersJson['results'] ?? {}) as Map<String, dynamic>;
    final regionEntry = results[regionCode] as Map<String, dynamic>?;
    return regionEntry?['link'] as String?;
  }

  /// Simple data type for watch providers
  WatchProvider toWatchProvider(Map<String, dynamic> mp) {
    final id = (mp['provider_id'] as num?)?.toInt() ?? 0;
    final name = (mp['provider_name'] as String?) ?? '';
    final logo = imageUrl('w45', mp['logo_path'] as String?);
    return WatchProvider(id: id, name: name, logoUrl: logo ?? '');
  }

  List<WatchProvider> extractProvidersForKey(
    Map<String, dynamic> providersJson,
    String regionCode,
    String key,
  ) {
    final results = (providersJson['results'] ?? {}) as Map<String, dynamic>;
    final regionEntry = results[regionCode] as Map<String, dynamic>?;
    if (regionEntry == null) return const [];
    final list = (regionEntry[key] as List?) ?? const [];
    return list
        .map((e) => toWatchProvider(e as Map<String, dynamic>))
        .where((p) => p.logoUrl.isNotEmpty)
        .toList();
  }

  List<WatchProvider> extractFlatrateProviders(
    Map<String, dynamic> providersJson,
    String regionCode,
  ) {
    return extractProvidersForKey(providersJson, regionCode, 'flatrate');
  }

  List<WatchProvider> extractRentProviders(
    Map<String, dynamic> providersJson,
    String regionCode,
  ) {
    return extractProvidersForKey(providersJson, regionCode, 'rent');
  }

  List<WatchProvider> extractBuyProviders(
    Map<String, dynamic> providersJson,
    String regionCode,
  ) {
    return extractProvidersForKey(providersJson, regionCode, 'buy');
  }

  /// Fallback using networks logos (not region-validated; only used if region lists empty)
  List<String> providerLogoFromDetail(Map<String, dynamic> detail) {
    final networks = (detail['networks'] as List?) ?? const [];
    final out = <String>[];
    for (final n in networks) {
      final m = n as Map<String, dynamic>;
      final logoPath = m['logo_path'] as String?;
      final url = imageUrl('w45', logoPath);
      if (url != null) out.add(url);
    }
    return out;
  }

  // -------- Credits / Meta --------
  Future<Map<String, dynamic>> getTvCredits(int tvId) async {
    final res = await http.get(_u('/tv/$tvId/credits', {'language': 'en-US'}));
    if (res.statusCode != 200) {
      throw Exception('Credits failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> extractTopCast(
    Map<String, dynamic> credits, {
    int limit = 20,
  }) {
    final cast = (credits['cast'] as List?) ?? const [];
    return cast.take(limit).map<Map<String, dynamic>>((c) {
      final m = c as Map<String, dynamic>;
      final id = (m['id'] as num?)?.toInt();
      final name = m['name'] as String?;
      final character = m['character'] as String?;
      final profileUrl = imageUrl('w185', m['profile_path'] as String?);
      return {
        'id': id,
        'name': name,
        'character': character,
        'profileUrl': profileUrl,
      };
    }).toList();
  }

  List<String> extractCreators(Map<String, dynamic> detail) {
    final creators = (detail['created_by'] as List?) ?? const [];
    return creators
        .map((c) => (c as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String? extractStatus(Map<String, dynamic> detail) =>
      (detail['status'] as String?)?.trim();

  double? extractVoteAverage(Map<String, dynamic> detail) {
    final v = detail['vote_average'];
    if (v is num) return v.toDouble();
    return null;
  }

  List<Map<String, String?>> extractProductionCompanies(
    Map<String, dynamic> detail,
  ) {
    final pcs = (detail['production_companies'] as List?) ?? const [];
    return pcs.map<Map<String, String?>>((pc) {
      final m = pc as Map<String, dynamic>;
      final name = m['name'] as String?;
      final logo = imageUrl('w92', m['logo_path'] as String?);
      return {'name': name, 'logo': logo};
    }).toList();
  }

  List<String> extractGenres(Map<String, dynamic> detail) {
    final gs = (detail['genres'] as List?) ?? const [];
    return gs
        .map((g) => (g as Map<String, dynamic>)['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<int> extractEpisodeRunTimes(Map<String, dynamic> detail) {
    final rts = (detail['episode_run_time'] as List?) ?? const [];
    return rts
        .map((n) => n is num ? n.toInt() : 0)
        .where((n) => n > 0)
        .toList();
  }

  String? extractFirstAirDate(Map<String, dynamic> detail) =>
      ((detail['first_air_date'] as String?)?.isEmpty ?? true)
      ? null
      : detail['first_air_date'] as String?;

  String? extractLastAirDate(Map<String, dynamic> detail) =>
      ((detail['last_air_date'] as String?)?.isEmpty ?? true)
      ? null
      : detail['last_air_date'] as String?;

  // -------- Person --------
  Future<Map<String, dynamic>> getPerson(int personId) async {
    final res = await http.get(_u('/person/$personId', {'language': 'en-US'}));
    if (res.statusCode != 200) {
      throw Exception('Person failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPersonCombinedCredits(int personId) async {
    final res = await http.get(
      _u('/person/$personId/combined_credits', {'language': 'en-US'}),
    );
    if (res.statusCode != 200) {
      throw Exception('Combined credits failed: ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String? personProfileUrl(Map<String, dynamic> person) {
    return imageUrl('w300', person['profile_path'] as String?);
  }

  List<Map<String, String?>> extractCreditsList(Map<String, dynamic> combined) {
    final cast = (combined['cast'] as List?) ?? const [];
    final out = <Map<String, String?>>[];
    for (final c in cast) {
      final m = c as Map<String, dynamic>;
      final mediaType = (m['media_type'] as String?) ?? '';
      final id = (m['id'] as num?)?.toInt();
      final title = mediaType == 'movie'
          ? (m['title'] as String?) ?? (m['original_title'] as String?) ?? ''
          : (m['name'] as String?) ?? (m['original_name'] as String?) ?? '';
      final poster = imageUrl('w342', m['poster_path'] as String?);
      final date = mediaType == 'movie'
          ? (m['release_date'] as String?)
          : (m['first_air_date'] as String?);
      final year = (date != null && date.length >= 4)
          ? date.substring(0, 4)
          : null;
      final character = m['character'] as String?;

      if (title.isEmpty) continue;
      out.add({
        'id': id?.toString(),
        'title': title,
        'poster': poster,
        'media_type': mediaType,
        'year': year,
        'character': character,
      });
    }
    out.sort((a, b) {
      final ay = int.tryParse(a['year'] ?? '') ?? -1;
      final by = int.tryParse(b['year'] ?? '') ?? -1;
      return by.compareTo(ay);
    });
    return out;
  }
}

class WatchProvider {
  final int id;
  final String name;
  final String logoUrl;
  const WatchProvider({
    required this.id,
    required this.name,
    required this.logoUrl,
  });
}
