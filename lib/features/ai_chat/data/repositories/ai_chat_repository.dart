import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../watchlist/data/models/watchlist_movie_model.dart';
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
    required List<WatchlistMovieModel> watchlist,
  }) async {
    final key = (apiKey ?? ApiConstants.geminiApiKey).trim();
    if (key.isEmpty) {
      throw const NetworkException(
        'Gemini API key is not configured. Add GEMINI_API_KEY to your .env file.',
        code: 'missing_gemini_key',
        isAuthConfigError: true,
      );
    }

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
          {'text': _buildSystemInstruction(watchlist)},
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

  String _buildSystemInstruction(List<WatchlistMovieModel> watchlist) {
    final wantToWatch = watchlist.where((m) => !m.isWatched).toList();
    final watched = watchlist.where((m) => m.isWatched).toList();

    String formatMovies(List<WatchlistMovieModel> items) {
      if (items.isEmpty) return 'None';
      return items
          .map((m) {
            final ratingPart = m.userRating != null
                ? ', User rated ${m.userRating}/5'
                : '';
            final notePart = m.userNote != null && m.userNote!.trim().isNotEmpty
                ? ' — Note: "${m.userNote!.trim()}"'
                : '';
            return '- ${m.title} (${Formatters.releaseYear(m.releaseDate)}, '
                'TMDB ${Formatters.rating(m.voteAverage)}$ratingPart)$notePart';
          })
          .join('\n');
    }

    return '''
You are CineList AI, an insightful and friendly movie concierge inside the CineList app.
Your job is to recommend movies and answer film questions tailored to the user's personal watchlist.

User's current watchlist (${watchlist.length} total movies):

Want to Watch (${wantToWatch.length}):
${formatMovies(wantToWatch)}

Already Watched (${watched.length}):
${formatMovies(watched)}

Response Guidelines:
- Analyze the genres, directors, pacing, and themes implied by their Want to Watch and Already Watched lists.
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
