import 'package:flutter/material.dart';
import '../models/onboarding_page_models.dart';
import '../widgets/onboarding_button.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../widgets/onboarding_skip_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import LoginPage
// Import Client Register Screen
// Import Contractor Register Screen

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;
  String? _userType; // To store if the user chose 'client' or 'contractor'

  final List<OnboardingPageModel> onboardingPages = [
    OnboardingPageModel(
      title: "Willkommen bei Bauaufträge24!",
      description: "Die Plattform für Bauaufträge und Handwerker in der Schweiz. Finden Sie schnell und einfach passende Aufträge oder qualifizierte Handwerker.",
      imageAsset: "assets/images/welcome.png",
    ),
    OnboardingPageModel(
      title: "Finden Sie Projekte & Fachleute",
      description: "Durchsuchen Sie aktuelle Bauprojekte oder bieten Sie Ihre Dienstleistungen als Handwerker an.",
      imageAsset: "assets/images/client_contractor.png",
    ),
    OnboardingPageModel(
      title: "Finden Sie vertrauenswürdige Fachkräfte",
      description: "Alle Handwerker werden sorgfältig geprüft und verifiziert, damit Sie sich auf Qualität verlassen können.",
      imageAsset: "assets/images/client.png",
    ),
    OnboardingPageModel(
      title: "Erhalten Sie schneller neue Aufträge",
      description: "Erstellen Sie Ihr Profil, erhalten Sie Benachrichtigungen und sichern Sie sich neue Bauaufträge in Ihrer Region.",
      imageAsset: "assets/images/contractor.png",
    ),
    OnboardingPageModel(
      title: "Los geht's!",
      description: "Registrieren Sie sich jetzt kostenlos und entdecken Sie die Vorteile von Bauaufträge24.",
      imageAsset: "assets/images/get_started.png",
    ),
  ];

 void _nextPage() {
  setState(() {
    if (_currentIndex == 0) {
      // Welcome -> ChoosingPage
      _currentIndex = 1;
    } 
    else if (_currentIndex == 1) {
      // ChoosingPage -> Route based on user type
      if (_userType == 'client') {
        _currentIndex = 2; // Go to ClientPage
      } else if (_userType == 'contractor') {
        _currentIndex = 3; // Go to ContractorPage
      }
    } 
    else if ((_currentIndex == 2 && _userType == 'client') ||
             (_currentIndex == 3 && _userType == 'contractor')) {
      // From either ClientPage or ContractorPage -> GetStarted
      _currentIndex = 4;
    } 
    else if (_currentIndex == 4) {
      // From GetStarted -> Navigate to login or register
      Navigator.pushNamed(context, '/login'); // route logic
    }
  });
}

  void _previousPage() {
    if (_currentIndex > 0) {
      setState(() {
        if (_currentIndex == 4) {
          // Go back to the appropriate info page
          _currentIndex = _userType == 'client' ? 3 : 2;
        } else if (_currentIndex == 2 || _currentIndex == 3) {
          _currentIndex = 1; // Go back to role selection
        } else {
          _currentIndex--;
        }
      });
    }
  }

  void _skip() {
    setState(() {
      _currentIndex = onboardingPages.length - 1;
    });
  }

  void _handleRoleSelection(String role) {
    setState(() {
      _userType = role;
    });
    _nextPage(); // Move to the next relevant page
  }

  //indicator login
  int getVisualIndex(int index) {
    if (index == 0) return 0; // Welcome
    if (index == 1) return 1; // ChoosingPage
    if (index == 2 || index == 3) return 2; // ClientPage OR ContractorPage
    if (index == 4) return 3; // GetStarted
    return 0;
  }


  //register navigation
  void _navigateToRegister() {
    if (_userType == 'client') {
      Navigator.pushNamed(context, '/register_client');
    } else if (_userType == 'contractor') {
      Navigator.pushNamed(context, '/register_contractor');
    } else {
      Navigator.pushNamed(context, '/register_client');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFD),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: List.generate(onboardingPages.length, (index) {
                  final page = onboardingPages[index];
                  return AnimatedOpacity(
                    opacity: _currentIndex == index ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Visibility(
                      visible: _currentIndex == index,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Image.asset(page.imageAsset),
                            ),
                            const SizedBox(height: 30),
                            Text(
                              page.title,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.description,
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            OnboardingPageIndicator(
              currentIndex: getVisualIndex(_currentIndex),  // use visual index here
              pageCount: 4,
            ),


            //role selection
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (_currentIndex == 1) ...[
                    SizedBox(
                      width: 150,
                      height: 50,
                        child: ElevatedButton(
                        onPressed: () => _handleRoleSelection('client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Auftraggeber', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      height: 50,
                        child: ElevatedButton(
                        onPressed: () => _handleRoleSelection('contractor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Firma', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else if (_currentIndex == 4) ...[
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('has_seen_onboarding', true);
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Login', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('has_seen_onboarding', true);
                          _navigateToRegister();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Registrieren', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ] else if (_currentIndex != onboardingPages.length - 1) ...[
                    OnboardingButton(
                        text: 'Wiiter',
                      onPressed: _nextPage,
                    ),
                    OnboardingSkipButton(onPressed: _skip),
                  ] else ...[
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.red.shade800,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}