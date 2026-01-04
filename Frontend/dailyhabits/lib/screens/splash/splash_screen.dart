import 'package:flutter/material.dart';
import 'package:dailyhabits/screens/onboarding/onboarding_carousel.dart';
import 'package:dailyhabits/screens/auth/login_screen.dart';
import 'package:dailyhabits/screens/home/home_page.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _backgroundController;

  // Logo animations
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _logoFadeAnimation;

  // Text animations
  late final Animation<double> _textFadeAnimation;
  late final Animation<Offset> _textSlideAnimation;

  // Background animation
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

  // ----------------------- Animation Setup -----------------------
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

  void _playAnimations() {
    _backgroundController.repeat(reverse: true);
    _logoController.forward();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });
  }

  // ----------------------- Navigation Logic -----------------------
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool('onboardingComplete') ?? false;
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!onboardingComplete) {
      _navigateTo(const OnboardingCarousel());
    } else if (!isLoggedIn) {
      _navigateTo(const LoginScreen());
    } else {
      _navigateTo(const HomePage());
    }
  }

  void _navigateTo(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  // ----------------------- UI Rendering -----------------------
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

  // ----------------------- UI Components -----------------------
  BoxDecoration _buildAnimatedGradient() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            const Color(0xFF5B6FED),
            const Color(0xFF4E5FDC),
            _backgroundPulseAnimation.value - 1.0,
          )!,
          Color.lerp(
            const Color(0xFFA855F7),
            const Color(0xFF9333EA),
            _backgroundPulseAnimation.value - 1.0,
          )!,
        ],
      ),
    );
  }

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.check, size: 75, color: Color(0xFFA855F7)),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTitle() {
    return SlideTransition(
      position: _textSlideAnimation,
      child: FadeTransition(
        opacity: _textFadeAnimation,
        child: const Text(
          'DailyHabits',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

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
                Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
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
