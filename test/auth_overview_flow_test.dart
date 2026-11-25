import 'package:cine_list/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:cine_list/features/auth/presentation/cubit/auth_state.dart';
import 'package:cine_list/features/auth/presentation/screens/auth_screen.dart';
import 'package:cine_list/features/landing/presentation/screens/web_landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthCubit extends Mock implements AuthCubit {}

void main() {
  testWidgets(
    'Overview Explore as Guest navigates to Discover and Login redirects straight to Discover',
    (tester) async {
      final authCubit = MockAuthCubit();
      when(() => authCubit.state).thenReturn(
        const AuthState(status: AuthStatus.unauthenticated),
      );
      when(() => authCubit.stream).thenAnswer(
        (_) => Stream<AuthState>.fromIterable([
          const AuthState(status: AuthStatus.unauthenticated),
        ]),
      );

      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (context, _) => WebLandingScreen(
              onSignIn: () => context.go('/auth'),
              onGetStarted: () => context.go('/auth'),
              onBrowseAsGuest: () => context.go('/discover'),
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const AuthScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('Discover Home')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Overview appears first for guests.
      expect(find.text('Explore as Guest'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('Explore as Guest').first);
      await tester.pumpAndSettle();

      expect(find.text('Discover Home'), findsOneWidget);
    },
  );
}
