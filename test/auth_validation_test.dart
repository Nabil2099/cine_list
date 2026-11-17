import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cine_list/features/auth/data/repositories/auth_repository.dart';
import 'package:cine_list/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cine_list/features/auth/presentation/cubit/auth_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

void main() {
  group('Auth Form Validation', () {
    test('validateEmail rejects empty and malformed emails', () {
      expect(AuthCubit.validateEmail(''), isNotNull);
      expect(AuthCubit.validateEmail('   '), isNotNull);
      expect(AuthCubit.validateEmail('invalid-email'), isNotNull);
      expect(AuthCubit.validateEmail('user@domain'), isNotNull);
    });

    test('validateEmail accepts valid emails', () {
      expect(AuthCubit.validateEmail('yami@cinelist.app'), isNull);
      expect(AuthCubit.validateEmail('  alex.smith@uni.edu  '), isNull);
    });

    test('validatePassword enforces non-empty and min length 6', () {
      expect(AuthCubit.validatePassword(''), isNotNull);
      expect(AuthCubit.validatePassword('12345'), isNotNull);
      expect(AuthCubit.validatePassword('123456'), isNull);
      expect(AuthCubit.validatePassword('securePass!'), isNull);
    });

    test('validateDisplayName enforces non-empty, min 2, and max 40 chars', () {
      expect(AuthCubit.validateDisplayName(''), isNotNull);
      expect(AuthCubit.validateDisplayName(' '), isNotNull);
      expect(AuthCubit.validateDisplayName('A'), isNotNull);
      expect(AuthCubit.validateDisplayName('A' * 41), isNotNull);
      expect(AuthCubit.validateDisplayName('Yami'), isNull);
      expect(AuthCubit.validateDisplayName('  Alex Smith  '), isNull);
    });
  });

  group('AuthCubit Email Verification', () {
    late MockAuthRepository repository;
    late StreamController<User?> authController;
    late MockUser unverifiedUser;
    late MockUser verifiedUser;

    setUp(() {
      repository = MockAuthRepository();
      authController = StreamController<User?>.broadcast();
      unverifiedUser = MockUser();
      verifiedUser = MockUser();

      when(() => unverifiedUser.uid).thenReturn('uid-1');
      when(() => unverifiedUser.email).thenReturn('yami@cinelist.app');
      when(() => unverifiedUser.displayName).thenReturn('Yami');
      when(() => unverifiedUser.emailVerified).thenReturn(false);

      when(() => verifiedUser.uid).thenReturn('uid-1');
      when(() => verifiedUser.email).thenReturn('yami@cinelist.app');
      when(() => verifiedUser.displayName).thenReturn('Yami');
      when(() => verifiedUser.emailVerified).thenReturn(true);

      when(() => repository.authStateChanges)
          .thenAnswer((_) => authController.stream);
    });

    tearDown(() async {
      await authController.close();
    });

    blocTest<AuthCubit, AuthState>(
      'emits unverified when user email is not verified and transitions to authenticated after reload',
      build: () {
        when(() => repository.reloadCurrentUser())
            .thenAnswer((_) async => verifiedUser);
        return AuthCubit(repository);
      },
      act: (cubit) async {
        authController.add(unverifiedUser);
        await Future<void>.delayed(Duration.zero);
        await cubit.checkEmailVerification();
      },
      verify: (cubit) {
        expect(cubit.state.status, AuthStatus.authenticated);
        verify(() => repository.reloadCurrentUser()).called(1);
      },
    );

    blocTest<AuthCubit, AuthState>(
      'resendVerificationEmail calls repository and emits infoMessage',
      build: () {
        when(() => repository.sendEmailVerification()).thenAnswer((_) async {});
        return AuthCubit(repository);
      },
      act: (cubit) async {
        authController.add(unverifiedUser);
        await Future<void>.delayed(Duration.zero);
        await cubit.resendVerificationEmail();
      },
      verify: (cubit) {
        verify(() => repository.sendEmailVerification()).called(1);
        expect(
          cubit.state.infoMessage,
          'Verification link resent to yami@cinelist.app.',
        );
      },
    );
  });
}
