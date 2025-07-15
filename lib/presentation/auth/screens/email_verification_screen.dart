import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EmailVerificationScreen extends StatefulWidget {
  final String? token;
  final String? keyParam;
  const EmailVerificationScreen({Key? key, this.token, this.keyParam}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  String status = "Verifying...";
  bool _hasVerificationParams = false;

  @override
  void initState() {
    super.initState();
    _hasVerificationParams = widget.token != null && widget.keyParam != null;
    if (_hasVerificationParams) {
      _verifyEmail();
    }
  }

  Future<void> _verifyEmail() async {
    if (widget.token == null || widget.keyParam == null) {
      setState(() => status = "Invalid verification link.");
      return;
    }
    try {
      final res = await http.post(
        Uri.parse("https://xn--bauauftrge24-ncb.ch/wp-json/custom-api/v1/verify-email"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.token,
          'key': widget.keyParam,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        setState(() => status = "Email Verified");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      } else {
        setState(() => status = data['message'] ?? "Verification failed.");
      }
    } catch (e) {
      setState(() => status = "Something went wrong. Please try again.");
    }
  }

  Widget _buildStatusContent() {
    if (status == "Verifying...") {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/email_verification.png', height: 80),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text("Mir prüefed dini E-Mail...", style: TextStyle(fontSize: 18)),
        ],
      );
    } else if (status == "Email Verified" || status.contains("verified")) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/success.png', height: 80),
          const SizedBox(height: 24),
          const Text("Dini E-Mail isch erfolgrich bestätigt worde!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 12),
          const Text("Du wirsch gli zum Login witergleitet.", textAlign: TextAlign.center),
        ],
      );
    } else if (status == "Invalid verification link.") {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/invalid.png', height: 80),
          const SizedBox(height: 24),
          const Text("Ungültige Verifizierigslink.", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          const Text("Bitte prüef de Link oder fordere neui E-Mail aa.", textAlign: TextAlign.center),
        ],
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/error.png', height: 80),
          const SizedBox(height: 24),
          const Text("Fähler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 12),
          Text(status, textAlign: TextAlign.center),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasVerificationParams) {
      return Scaffold(
        appBar: AppBar(title: const Text("Email Verification")),
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildStatusContent(),
          ),
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFD),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/email_verification.png',
                  height: 200,
                ),
                const Text(
                  'Bitte bestätigen Sie Ihre E-Mail-Adresse',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Wir haben Ihnen eine E-Mail gesendet. Bitte klicken Sie auf den Bestätigungslink.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Anmelden',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
