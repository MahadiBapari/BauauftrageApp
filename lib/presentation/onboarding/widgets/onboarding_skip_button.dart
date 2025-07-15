import 'package:flutter/material.dart';

class OnboardingSkipButton extends StatelessWidget {
  final VoidCallback onPressed;

  const OnboardingSkipButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: const Text(
        'Überspringen',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }
}
