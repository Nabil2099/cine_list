import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Manages authentication state, login, registration, password reset, and logout.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository) : super(const AuthState()) {
    _authSubscription = _authRepository.authStateChanges.listen(
      _onAuthStateChanged,
      onError: (_) => emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isLoading: false,
        ),
      ),
    );
  }

  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;

  static final RegExp _emailRegex = RegExp(
    r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,}$',
  );

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email is required.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Display name is required.';
    }
    if (trimmed.length < 2) {
      return 'Display name must be at least 2 characters.';
    }
    if (trimmed.length > 40) {
      return 'Display name must be 40 characters or fewer.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Password is required.';
    }
    if (raw.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  void _onAuthStateChanged(User? user) {
    if (user != null) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
          clearError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearUser: true,
          isLoading: false,
        ),
      );
    }
  }

  void toggleMode() {
    emit(
      state.copyWith(
        isRegisterMode: !state.isRegisterMode,
        clearError: true,
        clearInfo: true,
      ),
    );
  }

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearInfo: true));
  }

  Future<void> submit({
    required String email,
    required String password,
    String displayName = '',
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearInfo: true));

    try {
      final user = state.isRegisterMode
          ? await _authRepository.registerWithEmail(
              email: email,
              password: password,
              displayName: displayName,
            )
          : await _authRepository.signInWithEmail(
              email: email,
              password: password,
            );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isLoading: false,
          clearError: true,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Authentication failed. Please try again.',
        ),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearInfo: true));
    try {
      await _authRepository.sendPasswordResetEmail(email);
      emit(
        state.copyWith(
          isLoading: false,
          infoMessage: 'Password reset link sent to ${email.trim()}.',
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await _authRepository.signOut();
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        isLoading: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
