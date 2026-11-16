import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated cinematic splash screen shown while CineList initializes.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _loopController;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _iconScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.30, 0.78, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.30, 0.78, curve: Curves.easeOutCubic),
          ),
        );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.50, 0.98, curve: Curves.easeOut),
      ),
    );
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.50, 0.98, curve: Curves.easeOutCubic),
          ),
        );
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient breathing spotlight background
          AnimatedBuilder(
            animation: _loopController,
            builder: (context, _) {
              final pulse =
                  0.5 + 0.5 * math.sin(_loopController.value * 2 * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.12),
                    radius: 0.85 + (0.12 * pulse),
                    colors: [
                      AppColors.pacificBlue.withValues(
                        alpha: 0.16 + 0.08 * pulse,
                      ),
                      AppColors.softPeriwinkle.withValues(alpha: 0.08),
                      AppColors.surfaceBase,
                      AppColors.black,
                    ],
                    stops: const [0.0, 0.35, 0.72, 1.0],
                  ),
                ),
              );
            },
          ),

          // Main centered branding + loader
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Animated logo with rotating luminous ring
                FadeTransition(
                  opacity: _iconFade,
                  child: ScaleTransition(
                    scale: _iconScale,
                    child: SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _loopController,
                            builder: (context, _) {
                              return Transform.rotate(
                                angle: _loopController.value * 2 * math.pi,
                                child: CustomPaint(
                                  size: const Size(148, 148),
                                  painter: _OrbitRingPainter(),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.pacificBlue.withValues(
                                    alpha: 0.32,
                                  ),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Staggered Title
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: const Text(
                      'CineList',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Staggered Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: const Text(
                      'DISCOVER · SAVE · WATCH',
                      style: TextStyle(
                        color: AppColors.khakiBeige,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom animated loading bar & status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedShimmerBar(controller: _loopController),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, _) {
                          final dotCount =
                              ((_loopController.value * 4).floor() % 4);
                          final dots = '.' * dotCount;
                          return Text(
                            'Loading your cinema$dots',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width / 2) - 4;

    final trackPaint = Paint()
      ..color = AppColors.surfaceBorder.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.pacificBlue,
          AppColors.softPeriwinkle,
          AppColors.khakiBeige,
          Colors.transparent,
        ],
        stops: [0.0, 0.25, 0.55, 0.80, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 1.35,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedShimmerBar extends StatelessWidget {
  const _AnimatedShimmerBar({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        width: double.infinity,
        color: AppColors.surfaceElevated,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return FractionallySizedBox(
              alignment: Alignment(-1.0 + (controller.value * 2.0), 0),
              widthFactor: 0.38,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.pacificBlue,
                      AppColors.softPeriwinkle,
                      AppColors.khakiBeige,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
