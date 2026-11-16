/// Typed application exceptions for clean error mapping across layers.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.isAuthConfigError = false});

  final String message;
  final String? code;
  final bool isAuthConfigError;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.isAuthConfigError});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class WatchlistException extends AppException {
  const WatchlistException(super.message, {super.code});
}
