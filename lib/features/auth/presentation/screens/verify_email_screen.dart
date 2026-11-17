import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/auth_backdrop.dart';

/// Screen shown to signed-in users whose email address is not yet verified.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthCubit>().checkEmailVerification(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            (prev.errorMessage != curr.errorMessage &&
                curr.errorMessage != null) ||
            (prev.infoMessage != curr.infoMessage && curr.infoMessage != null),
        listener: (context, state) {
          final message = state.errorMessage ?? state.infoMessage;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: state.errorMessage != null
                      ? AppColors.error
                      : AppColors.surfaceElevated,
                ),
              );
            context.read<AuthCubit>().clearMessages();
          }
        },
        builder: (context, state) {
          final email = state.user?.email ?? 'your email';

          return SingleChildScrollView(
            child: Column(
              children: [
                const AuthBackdrop(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.pacificBlue.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.pacificBlue.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_outlined,
                              color: AppColors.pacificBlue,
                              size: 34,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Verify Your Email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'We sent a verification link to\n$email',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.khakiBeige,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Open your inbox (or spam folder), tap the verification link, and then tap the button below to continue.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: 'I\'ve Verified My Email',
                            isLoading: state.isLoading,
                            onPressed: () => context
                                .read<AuthCubit>()
                                .checkEmailVerification(),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: state.isLoading
                                  ? null
                                  : () => context
                                        .read<AuthCubit>()
                                        .resendVerificationEmail(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 19),
                              label: const Text('Resend Verification Email'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: state.isLoading
                                ? null
                                : () => context.read<AuthCubit>().signOut(),
                            child: const Text(
                              'Use Another Account',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

