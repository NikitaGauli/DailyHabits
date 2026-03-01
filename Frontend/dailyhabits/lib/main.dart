// DailyHabits — Application Entry Point
//
// Bootstraps the Flutter binding, configures system UI chrome, registers
// top-level [ChangeNotifier] providers, and launches the root [MyApp]
// widget which resolves theming and initial routing.
//
// Provider tree (registered here):
// - [ThemeProvider]          — light / dark / system theme management.
// - [HomeController]         — home-screen habit list state.
// - [NotificationController] — in-app notification state.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dailyhabits/screens/splash/splash_screen.dart';
import 'package:dailyhabits/theme/app_theme.dart';
import 'package:dailyhabits/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:dailyhabits/screens/home/home_controller.dart';
import 'package:dailyhabits/screens/notifications/notification_controller.dart';
import 'package:dailyhabits/screens/gamification/gamification_controller.dart';

// ==========================================================================
//  Bootstrap
// ==========================================================================

/// Application entry point.
///
/// 1. Ensures the Flutter engine is initialised.
/// 2. Sets a transparent status bar for edge-to-edge rendering.
/// 3. Wraps the widget tree in a [MultiProvider] to expose app-wide state.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Make the status bar transparent so content can draw edge-to-edge.
  // The overlay style is further refined by MyApp based on the active theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => NotificationController()),
        ChangeNotifierProvider(create: (_) => GamificationController()),
      ],
      child: const MyApp(),
    ),
  );
}

// ==========================================================================
//  Root Widget
// ==========================================================================

/// Root widget that configures [MaterialApp] with theme, routing, and the
/// initial screen ([SplashScreen]).
///
/// Listens to [ThemeProvider] to reactively switch between light, dark, and
/// system-controlled themes without a full app restart.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtain the current theme mode from the provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DailyHabits',

      // Light and dark ThemeData are defined centrally in AppTheme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      // All routing is handled in-app (OTP flow). No deep links needed.
      // Default: splash screen handles auth checks and routing
      home: const SplashScreen(),
    );
  }
}
