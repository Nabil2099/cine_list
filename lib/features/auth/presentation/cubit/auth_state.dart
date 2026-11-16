import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.isRegisterMode = false,
    this.errorMessage,
    this.infoMessage,
  });

  final AuthStatus status;
  final User? user;
  final bool isLoading;
  final bool isRegisterMode;
  final String? errorMessage;
  final String? infoMessage;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool clearUser = false,
    bool? isLoading,
    bool? isRegisterMode,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    user?.uid,
    user?.displayName,
    isLoading,
    isRegisterMode,
    errorMessage,
    infoMessage,
  ];
}
