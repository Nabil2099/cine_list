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
    final contents = history
        .where((m) => !m.isError && m.text.trim().isNotEmpty)
        .map(
          (m) => {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
        )
        .toList();

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
