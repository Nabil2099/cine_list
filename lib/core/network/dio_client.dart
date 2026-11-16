import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../error/app_exception.dart';

/// Reusable Dio HTTP client configured for the TMDB REST API.
class DioClient {
  DioClient({Dio? dio, String? apiKey, String? accessToken})
    : _apiKey = apiKey ?? ApiConstants.tmdbApiKey,
      _accessToken = accessToken ?? ApiConstants.tmdbAccessToken,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 12),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_apiKey.trim().isNotEmpty) {
            options.queryParameters['api_key'] = _apiKey.trim();
          } else if (_accessToken.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${_accessToken.trim()}';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final String _apiKey;
  final String _accessToken;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (_apiKey.trim().isEmpty && _accessToken.trim().isEmpty) {
      throw const NetworkException(
        'TMDB API key is not configured. Add TMDB_API_KEY to your .env file.',
        code: 'missing_token',
        isAuthConfigError: true,
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw const NetworkException(
        'Unexpected response format received from TMDB.',
        code: 'invalid_response',
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  NetworkException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const NetworkException('Request cancelled.', code: 'cancelled');
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkException(
        'Connection timed out. Please check your internet and try again.',
        code: 'timeout',
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return const NetworkException(
        'No internet connection. Please check your network and retry.',
        code: 'no_internet',
      );
    }

    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? serverMessage;
    if (responseData is Map && responseData['status_message'] is String) {
      serverMessage = responseData['status_message'] as String;
    }

    if (statusCode == 401 || statusCode == 403) {
      return NetworkException(
        serverMessage ?? 'Invalid or unauthorized TMDB credentials. Please check your .env file.',
        code: 'unauthorized',
        isAuthConfigError: true,
      );
    }

    if (statusCode == 404) {
      return NetworkException(
        serverMessage ?? 'The requested movie could not be found.',
        code: 'not_found',
      );
    }

    if (statusCode == 429) {
      return const NetworkException(
        'Too many requests to TMDB. Please wait a moment and try again.',
        code: 'rate_limited',
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return const NetworkException(
        'TMDB service is temporarily unavailable. Please try again shortly.',
        code: 'server_error',
      );
    }

    return NetworkException(
      serverMessage ?? 'Unable to load movies right now. Please try again.',
      code: 'unknown',
    );
  }
}
