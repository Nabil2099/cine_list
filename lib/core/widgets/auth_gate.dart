import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Utilities and UI prompts for Guest Mode action gating.
abstract final class AuthGate {
  /// Returns `true` when the user is fully authenticated.
  static bool isSignedIn(BuildContext context) {
    return context.read<AuthCubit>().state.status == AuthStatus.authenticated;
  }

  /// Opens the `/auth` flow in either sign-in or registration mode, preserving
  /// the user's current path via `?from=` so they return after signing in.
  static void openAuth(
    BuildContext context, {
    bool register = false,
    String? returnPath,
    bool replace = false,
  }) {
    final authCubit = context.read<AuthCubit>();
    authCubit.setRegisterMode(register);

    final router = GoRouter.maybeOf(context);
    final rawTarget =
        returnPath ??
        router?.routerDelegate.currentConfiguration.uri.toString() ??
        '/discover';
    final encodedFrom = Uri.encodeComponent(
      rawTarget.startsWith('/') ? rawTarget : '/discover',
    );
    final authUri = '/auth?from=$encodedFrom';

    if (replace) {
      router?.go(authUri);
    } else {
      router?.push(authUri);
    }
  }

  /// Ensures the user is signed in before executing an account-specific action.
  ///
  /// Returns `true` immediately when signed in; otherwise presents a prompt
  /// inviting the guest to Sign In or Create Account and returns `false`.
  static Future<bool> requireAuth(
    BuildContext context, {
    required String actionLabel,
    String? description,
  }) async {
    if (isSignedIn(context)) return true;

    final router = GoRouter.maybeOf(context);
    final authCubit = context.read<AuthCubit>();
    final currentUri =
        router?.routerDelegate.currentConfiguration.uri.toString() ??
        '/discover';
    final isWide =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    void navigateToAuth({required bool register}) {
      authCubit.setRegisterMode(register);
      final encoded = Uri.encodeComponent(
        currentUri.startsWith('/') ? currentUri : '/discover',
      );
      router?.push('/auth?from=$encoded');
    }

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _AuthGatePromptContent(
              actionLabel: actionLabel,
              description: description,
              onSignIn: () {
                Navigator.of(dialogContext).pop();
                navigateToAuth(register: false);
              },
              onCreateAccount: () {
                Navigator.of(dialogContext).pop();
                navigateToAuth(register: true);
              },
              onContinueAsGuest: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
      return false;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: _AuthGatePromptContent(
          actionLabel: actionLabel,
          description: description,
          showHandle: true,
          onSignIn: () {
            Navigator.of(sheetContext).pop();
            navigateToAuth(register: false);
          },
          onCreateAccount: () {
            Navigator.of(sheetContext).pop();
            navigateToAuth(register: true);
          },
          onContinueAsGuest: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );

    return false;
  }
}

class _AuthGatePromptContent extends StatelessWidget {
  const _AuthGatePromptContent({
    required this.actionLabel,
    this.description,
    this.showHandle = false,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onContinueAsGuest,
  });

  final String actionLabel;
  final String? description;
  final bool showHandle;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 8),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.pacificBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.pacificBlue.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.movie_filter_rounded,
              color: AppColors.khakiBeige,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sign in to $actionLabel',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description ??
                'Create a free CineList account to sync your watchlist, ratings, reviews, and custom lists across Web and Mobile.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pacificBlue,
                foregroundColor: AppColors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onCreateAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.surfaceBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Create Free Account',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onContinueAsGuest,
            child: const Text(
              'Continue as Guest',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-pane prompt shown on personalized tabs when browsing as a guest.
class GuestPromptView extends StatelessWidget {
  const GuestPromptView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.pacificBlue.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, size: 40, color: AppColors.pacificBlue),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          AuthGate.openAuth(context, register: false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pacificBlue,
                        foregroundColor: AppColors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          AuthGate.openAuth(context, register: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              if (secondaryLabel != null && onSecondaryTap != null) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSecondaryTap,
                  child: Text(
                    secondaryLabel!,
                    style: const TextStyle(color: AppColors.khakiBeige),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
