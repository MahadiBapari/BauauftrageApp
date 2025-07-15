import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bauauftrage/core/network/safe_http.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false; 

  Future<void> login() async {
    const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/login/';
    const apiKey = '1234567890abcdef';

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await SafeHttp.safePost(context, Uri.parse(url), headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      }, body: json.encode({
        'username': _emailController.text,
        'password': _passwordController.text,
      }));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        final userId = responseData['user_id']?.toString();
        final username = responseData['username'] ?? 'Unbekannter Benutzer';
        final email = responseData['email'] ?? '';
        final displayName = responseData['display_name'] ?? '';
        final role = responseData['role'];
        final token = responseData['token'];

        if (userId != null && token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId);
          await prefs.setString('username', username);
          await prefs.setString('user_email', email);
          await prefs.setString('displayName', displayName);
          await prefs.setString('user_role', role);
          await prefs.setString('auth_token', token);

          print('Login successful! Token: $token'); 
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (Route<dynamic> route) => false,
            arguments: {'role': role},
          );
        } else {
          _showError('Anmeldung fehlgeschlagen: E-Mail oder Passwort ist falsch');
        }
      } else {
        _showError('Anmeldung fehlgeschlagen: E-Mail oder Passwort ist falsch');
      }
    } catch (e) {
      _showError('Anmeldung fehlgeschlagen: E-Mail oder Passwort ist falsch');
    } finally {
      if (mounted) { 
         setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 48, color: Color.fromARGB(255, 185, 7, 7)),
              const SizedBox(height: 16),
              const Text(
                'Passwort vergessen',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bitte geben Sie Ihre E-Mail-Adresse ein, um einen Link zum Zurücksetzen des Passworts zu erhalten.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-Mail-Adresse',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Abbrechen',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 185, 7, 7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 185, 7, 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (emailController.text.isNotEmpty) {
                          Navigator.of(ctx).pop();
                          _sendPasswordResetLink(emailController.text);
                        }
                      },
                      child: const Text('Senden', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendPasswordResetLink(String email) async {
    setState(() => _isLoading = true);
    const url = 'https://xn--bauauftrge24-ncb.ch/wp-json/custom/v1/forgot-password';
    try {
      final response = await http.post(Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': '1234567890abcdef',
          },
          body: json.encode({'email': email}));

      String message;
      Color backgroundColor;
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        message = responseData['message'] ?? 'Ein Link zum Zurücksetzen des Passworts wurde an Ihre E-Mail gesendet.';
        backgroundColor = const Color.fromARGB(129, 0, 0, 0);
      } else {
        final responseData = json.decode(response.body);
        message = responseData['message'] ?? 'Senden des Links fehlgeschlagen. Bitte überprüfen Sie die E-Mail-Adresse und versuchen Sie es erneut.';
        backgroundColor = const Color.fromARGB(160, 244, 67, 54);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: const Color.fromARGB(160, 244, 67, 54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return; 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(160, 244, 67, 54),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 400;
          final logoHeight = isSmall ? 70.0 : 100.0;
          final horizontalPadding = isSmall ? 12.0 : 24.0;
          final fieldFontSize = isSmall ? 15.0 : 16.0;
          final buttonFontSize = isSmall ? 16.0 : 18.0;
          final buttonPadding = isSmall ? 12.0 : 16.0;
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/logolight.png',
                        height: logoHeight,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Willkommen',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Melden Sie sich bei Ihrem Konto an, um fortzufahren',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-Mail',
                          hintText: 'Bitte geben Sie Ihre E-Mail ein',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        style: TextStyle(color: Colors.black, fontSize: fieldFontSize),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          hintText: 'Bitte geben Sie Ihr Passwort ein',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        style: TextStyle(color: Colors.black, fontSize: fieldFontSize),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _showForgotPasswordDialog();
                          },
                          child: Text(
                            'Passwort vergessen?',
                            style: TextStyle(color: Colors.grey[600], fontSize: isSmall ? 13 : 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => login(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: buttonPadding),
                          textStyle: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Anmelden'),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              "Sie haben noch kein Konto?",
                              style: TextStyle(color: Colors.grey[600], fontSize: isSmall ? 11 : 13),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.person_outline, color: Color.fromARGB(255, 185, 7, 7)),
                              onPressed: () {
                                Navigator.pushNamed(context, '/register_client');
                              },
                              label: const Text(
                                'Als Kunde Eintragen',
                                style: TextStyle(color: Color.fromARGB(255, 185, 7, 7)),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: Color.fromARGB(255, 185, 7, 7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextButton.icon(
                              icon: const Icon(Icons.business_center_outlined, color: Color.fromARGB(255, 185, 7, 7)),
                              onPressed: () {
                                Navigator.pushNamed(context, '/register_contractor');
                              },
                              label: const Text(
                                'Als Firma Eintragen',
                                style: TextStyle(color: Color.fromARGB(255, 185, 7, 7)),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: buttonPadding),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                foregroundColor: Color.fromARGB(255, 185, 7, 7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}