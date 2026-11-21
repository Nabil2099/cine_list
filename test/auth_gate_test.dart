import 'dart:async';

import 'package:cine_list/core/theme/app_theme.dart';
import 'package:cine_list/core/widgets/auth_gate.dart';
import 'package:cine_list/features/auth/data/repositories/auth_repository.dart';
import 'package:cine_list/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRepository authRepository;
  late StreamController<User?> authController;

  setUp(() {
    authRepository = MockAuthRepository();
    authController = StreamController<User?>.broadcast();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => authController.stream);
  });

  tearDown(() async {
    await authController.close();
  });

  testWidgets(
    'AuthGate.requireAuth shows Guest prompt when unauthenticated and returns false on dismiss',
    (tester) async {
      final cubit = AuthCubit(authRepository);
      authController.add(null);

      bool? gateResult;

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      gateResult = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'save movies to your Watchlist',
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sign in to save movies to your Watchlist'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Free Account'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      expect(gateResult, isFalse);
      await cubit.close();
    },
  );

  testWidgets(
    'AuthGate.requireAuth returns true immediately when user is authenticated',
    (tester) async {
      final user = MockUser();
      when(() => user.uid).thenReturn('uid-123');
      when(() => user.email).thenReturn('yami@cinelist.app');
      when(() => user.displayName).thenReturn('Yami');
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.providerData).thenReturn(const []);

      final cubit = AuthCubit(authRepository);
      authController.add(user);

      bool? gateResult;

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      gateResult = await AuthGate.requireAuth(
                        context,
                        actionLabel: 'save movies to your Watchlist',
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(gateResult, isTrue);
      expect(find.text('Continue as Guest'), findsNothing);
      await cubit.close();
    },
  );
}
