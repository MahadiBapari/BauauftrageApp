import 'package:flutter/material.dart';
import '../presentation/onboarding/screens/onboarding_screen.dart';
import '../presentation/auth/screens/login_page.dart';
import '../presentation/auth/screens/register_client_screen.dart';
import '../presentation/auth/screens/register_contractor_screen.dart';
import '../presentation/splash/screens/splash_screen.dart';
import '../presentation/home/main_screen.dart';
import '../presentation/home/support_and_help_page/support_and_help_page_screen.dart';
import '../presentation/home/my_favourite_page/my_favourite_page_screen.dart';
import '../presentation/home/my_membership_page/my_membership_page_screen.dart';
import '../presentation/home/partners_page/partners_page_screen.dart'; 
import '../presentation/auth/screens/reset_password_screen.dart';
import '../presentation/auth/screens/email_verification_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String registerClient = '/register_client';
  static const String registerContractor = '/register_contractor';
  static const String home = '/home';
  static const String supportAndHelp = '/support_and_help';
  static const String myContractor = '/my_contractor';
  static const String myMembership = '/my_membership';
  static const String partners = '/partners'; 
  static const String resetPassword = '/reset-password';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.onboarding: (context) => const OnboardingScreen(),
  AppRoutes.login: (context) => const LoginPage(),
  AppRoutes.registerClient: (context) => const RegisterClientPage(),
  AppRoutes.registerContractor: (context) => const RegisterContractorPage(),
  AppRoutes.home: (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final role = args?['role'] ?? 'um_contractor';
    return MainScreen(role: role);
  },
  AppRoutes.supportAndHelp: (context) => const SupportAndHelpPageScreen(),
  AppRoutes.myContractor: (context) => const MyFavouritePageScreen(),
  AppRoutes.myMembership: (context) => const MyMembershipPageScreen(),
  AppRoutes.partners: (context) => const PartnerScreen(), 
  AppRoutes.resetPassword: (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final token = args?['token'] as String? ?? '';
    return ResetPasswordScreen(token: token);
  },
};

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  Uri uri = Uri.parse(settings.name ?? '');
  if (uri.path == '/verify-deep-link') {
    final token = uri.queryParameters['token'];
    final key = uri.queryParameters['key'];
    return MaterialPageRoute(
      builder: (_) => EmailVerificationScreen(token: token, keyParam: key),
    );
  }
  // Fallback to named routes if not a deep link
  final builder = appRoutes[settings.name];
  if (builder != null) {
    return MaterialPageRoute(builder: builder, settings: settings);
  }
  // Unknown route
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(child: Text('404 - Seite nicht gefunden')),
    ),
  );
}
