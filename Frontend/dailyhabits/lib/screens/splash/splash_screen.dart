// =============================================================================
// splash_screen.dart — Application Launch Splash
// =============================================================================
// The very first screen the user sees when opening the DailyHabits app.
//
// Responsibilities:
//  • Plays branded entrance animations (logo scale, text slide, background
//    gradient pulse).
//  • Checks persistent storage for onboarding completion and authentication
//    tokens.
//  • Navigates to the correct destination after a 3-second showcase:
//    – [OnboardingCarousel] if the user has never completed onboarding.
//    – [LoginScreen] if onboarding is done but no auth token exists.
//    – [HomePage] if the user is fully authenticated.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/onboarding/onboarding_carousel.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/home/home_page.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------------------------------------------------------
/// SplashScreen
/// ---------------------------------------------------------------------------
/// Entry splash screen for the DailyHabits application.
/// Shows animations and navigates based on onboarding & login status.
/// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Internal state for [SplashScreen].
///
/// Manages three animation controllers:
///  • `_logoController` – scale + fade for the app logo.
///  • `_textController` – fade + slide for the app title.
///  • `_backgroundController` – repeating gradient pulse.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─────────────────────── Animation Controllers ───────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _backgroundController;

  // ───────────────────────── Logo Animations ─────────────────────────
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;

  // ───────────────────────── Text Animations ─────────────────────────
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _textSlideAnimation;

  // ─────────────────────── Background Animation ───────────────────────
  late final Animation<double> _backgroundPulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playAnimations();

    // Check login status after splash delay (3 seconds)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      _checkLoginStatus();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // ======================= Animation Setup =======================

  /// Initialises all animation controllers and their tween curves.
  void _setupAnimations() {
    // Background pulse animation
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _backgroundPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Text animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );
  }

  /// Starts all animations in sequence: background loop first, then
  /// logo, then text with a 400 ms stagger.
  void _playAnimations() {
    _backgroundController.repeat(reverse: true);
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });
  }

  // ======================= Navigation Logic =======================

  /// Reads [SharedPreferences] to determine the user’s login state and
  /// routes to the appropriate screen.
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool('onboardingComplete') ?? false;
    // Check for saved auth token (set by AuthService on login/register)
    final String? authToken = prefs.getString('auth_token');
    final bool isLoggedIn = authToken != null && authToken.isNotEmpty;

    if (!onboardingComplete) {
      _navigateTo(const OnboardingCarousel());
    } else if (!isLoggedIn) {
      _navigateTo(const LoginScreen());
    } else {
      _navigateTo(const HomePage());
    }
  }

  /// Helper to perform a push-replacement navigation to [page].
  void _navigateTo(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  // ======================= UI Rendering =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundPulseAnimation,
        builder: (context, child) {
          return Container(
            decoration: _buildAnimatedGradient(),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    _buildAnimatedLogo(),
                    const SizedBox(height: 32),
                    _buildAnimatedTitle(),
                    const Spacer(flex: 2),
                    _buildLoadingIndicator(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================= UI Components =======================

  /// Builds a [BoxDecoration] whose gradient colours subtly pulse using
  /// the [_backgroundPulseAnimation] value.
  BoxDecoration _buildAnimatedGradient() {
    final isDark = context.isDarkMode;
    final startBase = isDark ? AppColors.darkBg : AppColors.lightBg;
    final startPulse = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;
    final endBase = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final endPulse = isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            startBase,
            startPulse,
            _backgroundPulseAnimation.value - 1.0,
          )!,
          Color.lerp(
            endBase,
            endPulse,
            _backgroundPulseAnimation.value - 1.0,
          )!,
        ],
      ),
    );
  }

  /// Animated app logo with elastic scale and fade transitions,
  /// wrapped in a [Hero] for shared-element transitions.
  Widget _buildAnimatedLogo() {
    return FadeTransition(
      opacity: _logoFadeAnimation,
      child: ScaleTransition(
        scale: _logoScaleAnimation,
        child: Hero(
          tag: 'app_logo',
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: context.colors.accent,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: context.colors.accent.withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.check, size: 75, color: AppColors.textOnAccent),
          ),
        ),
      ),
    );
  }

  /// Animated "DailyHabits" title with slide and fade transitions.
  Widget _buildAnimatedTitle() {
    return SlideTransition(
      position: _textSlideAnimation,
      child: FadeTransition(
        opacity: _textFadeAnimation,
        child: Text(
          'DailyHabits',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  /// Loading spinner and "Getting ready…" label shown at the bottom
  /// of the splash screen.
  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _textFadeAnimation,
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Getting ready…',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
