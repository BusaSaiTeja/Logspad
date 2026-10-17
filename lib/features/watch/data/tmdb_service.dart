import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_logs/core/config/api_config.dart';

class TmdbSearchResult {
  const TmdbSearchResult({
    required this.title,
    this.year,
    this.posterUrl,
    this.synopsis,
    this.language,
    this.genres = const [],
    this.totalEpisodes,
  });

  final String title;
  final int? year;
  final String? posterUrl;
  final String? synopsis;
  final String? language;
  final List<String> genres;
  final int? totalEpisodes;
}

class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _omdbApiKey = ApiConfig.omdbApiKey;

  static const Map<int, String> _genreMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10765: 'Sci-Fi & Fantasy',
  };

  static bool _isTmdbBlocked = false;

  /// Searches movies with automatic multi-tier fallbacks: TMDB -> OMDB -> TVMaze.
  Future<List<TmdbSearchResult>> searchMovies(String title) async {
    final cleanQuery = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanQuery.isEmpty) return [];

    // Tier 1: Try TMDB Movies if not previously blocked by regional ISP
    if (!_isTmdbBlocked) {
      try {
        final tmdbResults = await _searchTmdbMovies(cleanQuery);
        if (tmdbResults.isNotEmpty) {
          return tmdbResults;
        }
      } catch (e) {
        _isTmdbBlocked = true;
        if (kDebugMode) print('[TMDB Movie] Blocked or timed out, caching OMDB bypass: $e');
      }
    }

    // Tier 2: Try OMDB (Universal CDN, IMDb IDs, fast fallback)
    try {
      final omdbResults = await _searchOmdb(cleanQuery);
      if (omdbResults.isNotEmpty) {
        return omdbResults;
      }
    } catch (e) {
      if (kDebugMode) print('[OMDB] Error: $e');
    }

    // Tier 3: Try TVMaze (100% Free, NO API key required, zero ISP blocks)
    try {
      final tvMazeResults = await _searchTvMaze(cleanQuery);
      if (tvMazeResults.isNotEmpty) {
        return tvMazeResults;
      }
    } catch (e) {
      if (kDebugMode) print('[TVMaze] Error: $e');
    }

    return [];
  }

  /// Searches OMDB for movies & series.
  Future<List<TmdbSearchResult>> _searchOmdb(String cleanQuery) async {
    final candidateKeys = <String>[
      if (_omdbApiKey.isNotEmpty) _omdbApiKey,
      'trilogy',
      'b7a547f2',
    ];

    for (final key in candidateKeys.toSet()) {
      try {
        final uri = Uri.https('www.omdbapi.com', '', {
          'apikey': key,
          's': cleanQuery,
        });

        final response = await _client.get(uri).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['Response'] == 'True') {
            final searchList = (data['Search'] as List<dynamic>?) ?? [];
            if (searchList.isEmpty) continue;
            final qLower = cleanQuery.toLowerCase();

            // Sort startsWith first
            searchList.sort((a, b) {
              final tA = (a['Title'] as String? ?? '').toLowerCase();
              final tB = (b['Title'] as String? ?? '').toLowerCase();
              final sA = tA.startsWith(qLower);
              final sB = tB.startsWith(qLower);
              if (sA && !sB) return -1;
              if (!sA && sB) return 1;
              return 0;
            });

            // Enrich the top results with detail lookups in parallel
            final results = await Future.wait(
              searchList.take(6).map((item) async {
                final map = item as Map<String, dynamic>;
                final imdbId = map['imdbID'] as String?;
                final poster = map['Poster'] as String?;
                final posterUrl = (poster != null && poster != 'N/A') ? poster : null;
                final yearStr = map['Year'] as String?;
                int? year;
                if (yearStr != null && yearStr.length >= 4) {
                  year = int.tryParse(yearStr.substring(0, 4));
                }

                String? synopsis;
                List<String> genres = [];
                if (map['Type'] == 'movie' && map.containsKey('Genre')) {
                  genres = (map['Genre'] as String)
                      .split(',')
                      .map((g) => g.trim())
                      .where((g) => g.isNotEmpty && g != 'N/A')
                      .toList();
                }

                // Quick detail fetch for top 3 to get full synopsis & genre
                if (imdbId != null && searchList.indexOf(item) < 3) {
                  try {
                    final detailUri = Uri.https('www.omdbapi.com', '', {
                      'apikey': key,
                      'i': imdbId,
                      'plot': 'short',
                    });
                    final detailRes =
                        await _client.get(detailUri).timeout(const Duration(seconds: 3));
                    if (detailRes.statusCode == 200) {
                      final dData = jsonDecode(detailRes.body) as Map<String, dynamic>;
                      if (dData['Plot'] != null && dData['Plot'] != 'N/A') {
                        synopsis = dData['Plot'] as String;
                      }
                      if (dData['Genre'] != null && dData['Genre'] != 'N/A') {
                        genres = (dData['Genre'] as String)
                            .split(',')
                            .map((g) => g.trim())
                            .where((g) => g.isNotEmpty)
                            .toList();
                      }
                    }
                  } catch (_) {}
                }

                return TmdbSearchResult(
                  title: (map['Title'] as String?) ?? cleanQuery,
                  year: year,
                  posterUrl: posterUrl,
                  synopsis: synopsis,
                  genres: genres,
                  language: 'ENGLISH',
                );
              }),
            );

            return results;
          }
        }
      } catch (e) {
        if (kDebugMode) print('[OMDB] Key $key failed: $e');
      }
    }
    return [];
  }

  /// TMDB Movie Search
  Future<List<TmdbSearchResult>> _searchTmdbMovies(String cleanQuery) async {
    if (ApiConfig.tmdbApiKey.isEmpty) return [];

    final uri = Uri.https('api.themoviedb.org', '/3/search/movie', {
      'api_key': ApiConfig.tmdbApiKey,
      'query': cleanQuery,
      'include_adult': 'false',
    });

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': 'LogspadApp/1.0 (Flutter)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 2));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) return [];

      _sortResultsByRelevance(results, cleanQuery, titleKey: 'title');

      return results.take(6).map((item) {
        final first = item as Map<String, dynamic>;
        final releaseDate = first['release_date'] as String?;
        int? year;
        if (releaseDate != null && releaseDate.length >= 4) {
          year = int.tryParse(releaseDate.substring(0, 4));
        }

        final posterPath = first['poster_path'] as String?;
        final posterUrl =
            posterPath != null ? '${ApiConfig.tmdbImageBaseUrl}$posterPath' : null;

        final genreIds =
            (first['genre_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
        final genres =
            genreIds.map((id) => _genreMap[id]).whereType<String>().toList();

        final langCode = first['original_language'] as String?;

        return TmdbSearchResult(
          title: (first['title'] as String?) ?? cleanQuery,
          year: year,
          posterUrl: posterUrl,
          synopsis: first['overview'] as String?,
          language: langCode?.toUpperCase(),
          genres: genres,
        );
      }).toList();
    }
    return [];
  }

  /// Searches TMDB, OMDB, and TVMaze for TV Shows and Anime series by title.
  Future<List<TmdbSearchResult>> searchTv(String title) async {
    final cleanQuery = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanQuery.isEmpty) return [];

    // Tier 1: TMDB TV Search
    if (!_isTmdbBlocked) {
      try {
        final tmdbTvResults = await _searchTmdbTv(cleanQuery);
        if (tmdbTvResults.isNotEmpty) {
          return tmdbTvResults;
        }
      } catch (e) {
        _isTmdbBlocked = true;
        if (kDebugMode) print('[TMDB TV] Error: $e');
      }
    }

    // Tier 2: OMDB
    try {
      final omdbResults = await _searchOmdb(cleanQuery);
      if (omdbResults.isNotEmpty) {
        return omdbResults;
      }
    } catch (_) {}

    // Tier 3: TVMaze (Zero API Key needed)
    try {
      final tvMazeResults = await _searchTvMaze(cleanQuery);
      if (tvMazeResults.isNotEmpty) {
        return tvMazeResults;
      }
    } catch (_) {}

    return [];
  }

  /// TMDB TV Show & Anime Search
  Future<List<TmdbSearchResult>> _searchTmdbTv(String cleanQuery) async {
    if (ApiConfig.tmdbApiKey.isEmpty) return [];

    final uri = Uri.https('api.themoviedb.org', '/3/search/tv', {
      'api_key': ApiConfig.tmdbApiKey,
      'query': cleanQuery,
      'include_adult': 'false',
    });

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': 'LogspadApp/1.0 (Flutter)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 2));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (data['results'] as List<dynamic>?) ?? [];
      if (results.isEmpty) return [];

      _sortResultsByRelevance(results, cleanQuery, titleKey: 'name');

      return results.take(6).map((item) {
        final first = item as Map<String, dynamic>;
        final firstAirDate = first['first_air_date'] as String?;
        int? year;
        if (firstAirDate != null && firstAirDate.length >= 4) {
          year = int.tryParse(firstAirDate.substring(0, 4));
        }

        final posterPath = first['poster_path'] as String?;
        final posterUrl =
            posterPath != null ? '${ApiConfig.tmdbImageBaseUrl}$posterPath' : null;

        final genreIds =
            (first['genre_ids'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
        final genres =
            genreIds.map((id) => _genreMap[id]).whereType<String>().toList();

        final langCode = first['original_language'] as String?;

        return TmdbSearchResult(
          title: (first['name'] as String?) ?? cleanQuery,
          year: year,
          posterUrl: posterUrl,
          synopsis: first['overview'] as String?,
          language: langCode?.toUpperCase(),
          genres: genres,
        );
      }).toList();
    }
    return [];
  }

  /// Searches TVMaze for shows and movies (100% Free, NO API key required).
  Future<List<TmdbSearchResult>> _searchTvMaze(String cleanQuery) async {
    final uri = Uri.https('api.tvmaze.com', '/search/shows', {
      'q': cleanQuery,
    });

    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': 'LogspadApp/1.0 (Flutter)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) return [];

      return list.take(6).map((item) {
        final show = (item as Map<String, dynamic>)['show'] as Map<String, dynamic>;
        final name = (show['name'] as String?) ?? cleanQuery;
        final premiered = show['premiered'] as String?;
        int? year;
        if (premiered != null && premiered.length >= 4) {
          year = int.tryParse(premiered.substring(0, 4));
        }
        final imageMap = show['image'] as Map<String, dynamic>?;
        final posterUrl = (imageMap?['original'] ?? imageMap?['medium']) as String?;
        final rawSummary = show['summary'] as String?;
        final synopsis = rawSummary?.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        final genres = ((show['genres'] as List<dynamic>?) ?? []).cast<String>();
        final lang = show['language'] as String?;

        return TmdbSearchResult(
          title: name,
          year: year,
          posterUrl: posterUrl,
          synopsis: synopsis,
          language: lang?.toUpperCase(),
          genres: genres,
        );
      }).toList();
    }
    return [];
  }

  /// Sorts items so titles starting with the query appear first.
  void _sortResultsByRelevance(List<dynamic> items, String query, {required String titleKey}) {
    final qLower = query.toLowerCase();
    items.sort((a, b) {
      final mapA = a as Map<String, dynamic>;
      final mapB = b as Map<String, dynamic>;

      final nameA = (mapA[titleKey] as String? ?? '').toLowerCase();
      final nameB = (mapB[titleKey] as String? ?? '').toLowerCase();

      final startsA = nameA.startsWith(qLower);
      final startsB = nameB.startsWith(qLower);

      if (startsA && !startsB) return -1;
      if (!startsA && startsB) return 1;
      return 0;
    });
  }
}
