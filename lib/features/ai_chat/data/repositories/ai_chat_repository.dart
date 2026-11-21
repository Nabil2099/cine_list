import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../community/data/models/movie_review_model.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
import '../models/ai_chat_context.dart';
import '../models/chat_message_model.dart';

/// Repository communicating with Google Gemini (`generateContent`) REST API
/// while grounding responses in the user's live Firestore watchlist and
/// optional Google AI Studio File Search store.
class AiChatRepository {
  AiChatRepository({Dio? dio, this.apiKey, this.fileSearchStore})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.geminiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              headers: const {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;
  final String? apiKey;
  final String? fileSearchStore;

  Future<String> sendMessage({
    required List<ChatMessageModel> history,
    AiChatContext context = const AiChatContext(),
  }) async {
    final key = (apiKey ?? ApiConstants.geminiApiKey).trim();
    if (key.isEmpty) {
      throw const NetworkException(
        'Gemini API key is not configured. Add GEMINI_API_KEY to your .env file.',
        code: 'missing_gemini_key',
        isAuthConfigError: true,
      );
    }

    final body = _buildRequestBody(history: history, context: context);
    return _generateText(body: body, key: key);
  }

  Stream<String> streamMessage({
    required List<ChatMessageModel> history,
    AiChatContext context = const AiChatContext(),
  }) async* {
    final key = (apiKey ?? ApiConstants.geminiApiKey).trim();
    if (key.isEmpty) {
      throw const NetworkException(
        'Gemini API key is not configured. Add GEMINI_API_KEY to your .env file.',
        code: 'missing_gemini_key',
        isAuthConfigError: true,
      );
    }

    final body = _buildRequestBody(history: history, context: context);

    try {
      final response = await _dio.post<ResponseBody>(
        '/models/${ApiConstants.geminiModel}:streamGenerateContent',
        queryParameters: {'alt': 'sse', 'key': key},
        data: body,
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw const NetworkException(
          'Gemini returned an empty stream.',
          code: 'empty_ai_response',
        );
      }

      var emittedAny = false;
      await for (final line
          in stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;

        try {
          final decoded = jsonDecode(payload);
          final chunk = _extractCandidateText(decoded);
          if (chunk.isNotEmpty) {
            emittedAny = true;
            yield chunk;
          }
        } catch (_) {
          // Ignore malformed SSE keepalive/partial lines.
        }
      }

      if (!emittedAny) {
        throw const NetworkException(
          'Gemini returned an empty response. Please try again.',
          code: 'empty_ai_response',
        );
      }
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildRequestBody({
    required List<ChatMessageModel> history,
    required AiChatContext context,
  }) {
    final validMessages = history
        .where((m) => !m.isError && (m.text.trim().isNotEmpty || m.hasImage))
        .toList();
    final lastImageIndex = validMessages.lastIndexWhere((m) => m.hasImage);

    final contents = <Map<String, dynamic>>[];
    for (var i = 0; i < validMessages.length; i++) {
      final m = validMessages[i];
      final parts = <Map<String, dynamic>>[];
      if (m.hasImage && i == lastImageIndex) {
        parts.add({
          'inlineData': {
            'mimeType': m.imageMimeType ?? 'image/jpeg',
            'data': m.imageBase64,
          },
        });
      }
      if (m.text.trim().isNotEmpty) {
        parts.add({'text': m.text});
      }
      if (parts.isNotEmpty) {
        contents.add({
          'role': m.isUser ? 'user' : 'model',
          'parts': parts,
        });
      }
    }

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': _buildSystemInstruction(context)},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 2048},
    };

    final storeName = (fileSearchStore ?? ApiConstants.geminiFileSearchStore)
        .trim();
    if (storeName.isNotEmpty) {
      body['tools'] = [
        {
          'fileSearch': {
            'fileSearchStoreNames': [storeName],
            'topK': 5,
          },
        },
      ];
    }
    return body;
  }

  String _extractCandidateText(dynamic data) {
    if (data is! Map) return '';
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final first = candidates.first;
    if (first is! Map) return '';
    final content = first['content'];
    if (content is! Map) return '';
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return '';
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }
    return buffer.toString();
  }

  /// Generates a concise, spoiler-free AI consensus from community reviews.
  Future<String> summarizeCommunityReviews({
    required String movieTitle,
    required List<MovieReviewModel> reviews,
  }) async {
    final key = (apiKey ?? ApiConstants.geminiApiKey).trim();
    if (key.isEmpty) {
      throw const NetworkException(
        'Gemini API key is not configured. Add GEMINI_API_KEY to your .env file.',
        code: 'missing_gemini_key',
        isAuthConfigError: true,
      );
    }

    final reviewLines = reviews
        .take(15)
        .map((r) => '- (${r.rating}/5) "${r.comment.replaceAll('\n', ' ')}"')
        .join('\n');

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {
            'text':
                'You summarize movie community reviews for CineList. '
                'Write 2-3 concise sentences describing what reviewers liked '
                'and any common criticisms. NEVER include plot spoilers.',
          },
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Summarize CineList community reviews for "$movieTitle":\n$reviewLines',
            },
          ],
        },
      ],
      'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 220},
    };

    return _generateText(body: body, key: key);
  }

  /// Uses Gemini to suggest tailored movie titles based on the user's watchlist.
  /// Returns an empty list if Gemini is unconfigured or unavailable.
  Future<List<({String title, String? year})>> recommendMovieTitles({
    required List<WatchlistMovieModel> watchlist,
    List<String> excludeTitles = const [],
    int count = 8,
  }) async {
    final key = (apiKey ?? ApiConstants.geminiApiKey).trim();
    if (key.isEmpty || watchlist.isEmpty) return const [];

    final loved = watchlist
        .where((m) => (m.userRating ?? 0) >= 4)
        .take(10)
        .map((m) => '${m.title} (${m.userRating}/5)')
        .toList();
    final wantList = watchlist
        .where((m) => !m.isWatched)
        .take(10)
        .map((m) => m.title)
        .toList();
    final watchedOther = watchlist
        .where((m) => m.isWatched && (m.userRating == null || m.userRating! < 4))
        .take(8)
        .map((m) => m.title)
        .toList();

    final promptBuffer = StringBuffer()
      ..writeln('Analyze this user\'s movie taste and recommend $count movies they have NOT seen yet.');
    if (loved.isNotEmpty) {
      promptBuffer.writeln('Highly rated: ${loved.join(', ')}');
    }
    if (wantList.isNotEmpty) {
      promptBuffer.writeln('Want to Watch: ${wantList.join(', ')}');
    }
    if (watchedOther.isNotEmpty) {
      promptBuffer.writeln('Also watched: ${watchedOther.join(', ')}');
    }
    final allWatchlistTitles = watchlist.take(30).map((m) => m.title).toList();
    promptBuffer.writeln(
      'Do NOT recommend any of these: ${[...allWatchlistTitles, ...excludeTitles].join(', ')}.',
    );
    promptBuffer.writeln(
      'Respond ONLY with a valid JSON array of objects like [{"title":"Movie Name","year":"2019"}]. No markdown or extra text.',
    );

    try {
      final raw = await _generateText(
        key: key,
        body: {
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'You are CineList\'s recommendation engine. Output strictly a raw JSON array of {"title": string, "year": string} objects with no markdown fences.',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': promptBuffer.toString()},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.85, 'maxOutputTokens': 512},
        },
      );

      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim();
      }
      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');
      if (start == -1 || end <= start) return const [];

      final decoded = jsonDecode(cleaned.substring(start, end + 1));
      if (decoded is! List) return const [];

      final picks = <({String title, String? year})>[];
      for (final item in decoded) {
        if (item is Map) {
          final title = (item['title'] as String?)?.trim() ?? '';
          final year = item['year']?.toString().trim();
          if (title.isNotEmpty) {
            picks.add((
              title: title,
              year: (year != null && year.isNotEmpty) ? year : null,
            ));
          }
        }
      }
      return picks;
    } catch (_) {
      return const [];
    }
  }

  Future<String> _generateText({
    required Map<String, dynamic> body,
    required String key,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/models/${ApiConstants.geminiModel}:generateContent',
        queryParameters: {'key': key},
        data: body,
      );

      final data = response.data;
      if (data is Map) {
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map) {
            final content = first['content'];
            if (content is Map) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                final textBuffer = StringBuffer();
                for (final part in parts) {
                  if (part is Map && part['text'] is String) {
                    textBuffer.write(part['text'] as String);
                  }
                }
                final reply = textBuffer.toString().trim();
                if (reply.isNotEmpty) return reply;
              }
            }
          }
        }
      }

      throw const NetworkException(
        'Gemini returned an empty response. Please try again.',
        code: 'empty_ai_response',
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  String _buildSystemInstruction(AiChatContext context) {
    final watchlist = context.watchlist;
    final upNext = watchlist
        .where((m) => !m.isWatched && m.isUpNext)
        .toList();
    final wantToWatch = watchlist
        .where((m) => !m.isWatched && !m.isUpNext)
        .toList();
    final watched = watchlist.where((m) => m.isWatched).toList();
    final byId = {for (final m in watchlist) m.movieId: m.title};

    String formatMovies(List<WatchlistMovieModel> items) {
      if (items.isEmpty) return 'None';
      return items
          .map((m) {
            final ratingPart = m.userRating != null
                ? ', User rated ${m.userRating}/5'
                : '';
            final rewatchPart = m.rewatchCount > 0
                ? ', Rewatched ×${m.rewatchCount}'
                : '';
            final notePart = m.userNote != null && m.userNote!.trim().isNotEmpty
                ? ' — Note: "${m.userNote!.trim()}"'
                : '';
            return '- ${m.title} (${Formatters.releaseYear(m.releaseDate)}, '
                'TMDB ${Formatters.rating(m.voteAverage)}$ratingPart$rewatchPart)$notePart';
          })
          .join('\n');
    }

    final collectionsSection = context.collections.isEmpty
        ? 'None'
        : context.collections
              .map((c) {
                final titles = c.movieIds
                    .map((id) => byId[id])
                    .whereType<String>()
                    .take(8)
                    .join(', ');
                return '- ${c.name} (${c.movieIds.length} movies): ${titles.isEmpty ? 'Empty' : titles}';
              })
              .join('\n');

    final challenge = context.activeChallenge;
    final challengeSection = challenge == null
        ? 'None'
        : '${challenge.title}: "${challenge.movieTitle}" (+${challenge.bonusPoints} Rep) — ${challenge.prompt}';

    final followedSection = context.followedReviews.isEmpty
        ? 'None'
        : context.followedReviews
              .take(8)
              .map(
                (r) =>
                    '- ${r.authorName} rated "${r.movieTitle}" ${r.rating}/5: "${r.comment.replaceAll('\n', ' ')}"',
              )
              .join('\n');

    return '''
You are CineList AI, an insightful and friendly movie concierge inside the CineList app.
Your job is to recommend movies and answer film questions tailored to the user's personal watchlist, collections, and community circle.

User's current watchlist (${watchlist.length} total movies):

Up Next Priority Queue (${upNext.length}):
${formatMovies(upNext)}

Want to Watch (${wantToWatch.length}):
${formatMovies(wantToWatch)}

Already Watched (${watched.length}):
${formatMovies(watched)}

Custom Collections (${context.collections.length}):
$collectionsSection

Active Community Watch Party:
$challengeSection

Recent Reviews from Followed Critics:
$followedSection

Response Guidelines:
- Pay special attention to their Up Next queue, 5/5 ratings, rewatched films, and custom collections to understand their core taste.
- Reference followed critics' reviews or the active Watch Party when relevant.
- When the user shares a photo (movie poster, DVD/Blu-ray shelf, cinema marquee, or film still), identify every visible movie title and release year accurately, format each one as **Movie Title (Year)** so CineList can render instant Watchlist cards, and briefly note which ones best fit their taste.
- Never recommend movies they have already watched unless they specifically ask about them.
- Format every recommendation cleanly using bullet points:
  - **Movie Title (Year)** — *Genre / Vibe*: 1–2 concise sentences explaining why it matches specific titles in their watchlist.
- Start with a brief 1-sentence personalized insight about their taste, and end with a short, helpful follow-up question (e.g. offering to narrow by mood, runtime, or decade).
- Keep the tone warm, concise, and easy to scan on a phone screen. Avoid filler or repeating the prompt.
- If their watchlist is empty, suggest 4–5 acclaimed, diverse starting picks and invite them to save favorites to their watchlist.
''';
  }

  NetworkException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkException(
        'AI request timed out. Please try again.',
        code: 'timeout',
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return const NetworkException(
        'No internet connection. Please check your network and try again.',
        code: 'no_internet',
      );
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? apiMessage;
    if (data is Map && data['error'] is Map) {
      final errObj = data['error'] as Map;
      if (errObj['message'] is String) {
        apiMessage = errObj['message'] as String;
      }
    }

    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      return NetworkException(
        apiMessage ?? 'Invalid Gemini API key or File Search configuration. Check your .env file.',
        code: 'unauthorized',
        isAuthConfigError: true,
      );
    }

    if (statusCode == 429) {
      return const NetworkException(
        'Gemini rate limit reached. Please wait a moment and try again.',
        code: 'rate_limited',
      );
    }

    return NetworkException(
      apiMessage ?? 'Unable to reach CineList AI right now. Please try again.',
      code: 'ai_error',
    );
  }
}
