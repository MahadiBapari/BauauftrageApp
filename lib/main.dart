import 'dart:async';
import 'package:bauauftrage/presentation/auth/screens/reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'routing/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  //testkey = pk_test_51R4IES4PgABMuYZqF1Hpx9wWxaBAEh5zVxM6SlHAlt65I0ek0ww3vrPV9EYSatNor7wfXKLMjbKEwPMfyLakPt9800OiKUhmut
  //livekey = pk_live_51R4IEKGByhgsCrrfWagwRb319gQEyYPq8Rjny4TAB0kzXr1F9UsXYiIsxCdS6negbScfR6PYKpctD9NHyP1ClC1a00sxj2EKv5

  // Set Stripe publishable key
  Stripe.publishableKey = 'pk_live_51R4IEKGByhgsCrrfWagwRb319gQEyYPq8Rjny4TAB0kzXr1F9UsXYiIsxCdS6negbScfR6PYKpctD9NHyP1ClC1a00sxj2EKv5';
  
  // For Apple Pay (and to ensure initialization is awaited)
  Stripe.merchantIdentifier = 'merchant.flutter.stripe.test';
  await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Listen for incoming links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleDeepLink(uri);
      }
    });

    // Handle the link that started the app
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      // Handle error
    }
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/reset-password')) {
      final token = uri.queryParameters['token'];
      if (token != null) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Bauaufträge24',
      theme: ThemeData(
        //primarySwatch: Colors.blue,
        // fontFamily: 'Poppins',
        // textTheme: const TextTheme(
        //   bodyText1: TextStyle(fontSize: 16.0, color: Colors.black),
        //   bodyText2: TextStyle(fontSize: 14.0, color: Colors.black54),
        // ),
          scaffoldBackgroundColor: const Color(0xFFFDF8F8), // ← your desired background color
          canvasColor: const Color(0xFFFDF8F8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 255, 255, 255), // ← your desired app bar color
            //iconTheme: IconThemeData(color: Colors.black),
            //titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
      ),
      
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: onGenerateRoute,
    );
  }
}