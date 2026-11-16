import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../widgets/auth_backdrop.dart';

/// Unified Login & Register screen matching the CineList reference design.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onBackToLanding});

  final VoidCallback? onBackToLanding;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetController = TextEditingController(text: _emailController.text);
    final dialogKey = GlobalKey<FormState>();

    final submittedEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Reset Password',
          style: TextStyle(color: AppColors.khakiBeige),
        ),
        content: Form(
          key: dialogKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email address and we will send you a reset link.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: resetController,
                hintText: 'Email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: AuthCubit.validateEmail,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.pacificBlue,
              foregroundColor: AppColors.black,
            ),
            onPressed: () {
              if (dialogKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(resetController.text.trim());
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );

    resetController.dispose();
    if (submittedEmail != null && mounted) {
      context.read<AuthCubit>().sendPasswordReset(submittedEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, curr) =>
            prev.infoMessage != curr.infoMessage && curr.infoMessage != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.infoMessage!)));
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              children: [
                const AuthBackdrop(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final isRegister = state.isRegisterMode;

                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (widget.onBackToLanding != null) ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: widget.onBackToLanding,
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Back to Overview'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                // Brand emblem
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.pacificBlue.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.pacificBlue.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.movie_filter_rounded,
                                    color: AppColors.khakiBeige,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Cine',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'List',
                                        style: TextStyle(
                                          color: AppColors.khakiBeige,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  AppConstants.appTagline,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  isRegister
                                      ? 'Create your personal movie watchlist'
                                      : 'Welcome back, ready for movie night?',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                CustomTextField(
                                  controller: _emailController,
                                  hintText: 'Email',
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  validator: AuthCubit.validateEmail,
                                ),
                                const SizedBox(height: 14),
                                CustomTextField(
                                  controller: _passwordController,
                                  hintText: 'Password',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: [
                                    isRegister
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  onFieldSubmitted: (_) => _onSubmit(),
                                  validator: AuthCubit.validatePassword,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                  ),
                                ),
                                if (!isRegister)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: state.isLoading
                                          ? null
                                          : _showForgotPasswordDialog,
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: AppColors.khakiBeige,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 18),
                                if (state.errorMessage != null) ...[
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            state.errorMessage!,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                PrimaryButton(
                                  label: isRegister
                                      ? 'Create Account'
                                      : 'Log In',
                                  isLoading: state.isLoading,
                                  onPressed: _onSubmit,
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isRegister
                                          ? 'Already have an account? '
                                          : "Don't have an account? ",
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: state.isLoading
                                          ? null
                                          : () {
                                              _formKey.currentState?.reset();
                                              context
                                                  .read<AuthCubit>()
                                                  .toggleMode();
                                            },
                                      child: Text(
                                        isRegister ? 'Log In' : 'Sign Up',
                                        style: const TextStyle(
                                          color: AppColors.pacificBlue,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
