import 'package:flutter/material.dart';

class OnboardingPageIndicator extends StatelessWidget {
  final int currentIndex;
  final int pageCount;

  const OnboardingPageIndicator({
    super.key,
    required this.currentIndex,
    required this.pageCount,
  });

  

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentIndex == index ? Colors.red.shade800 : Colors.grey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
