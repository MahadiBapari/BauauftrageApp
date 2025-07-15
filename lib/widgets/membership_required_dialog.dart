import 'package:flutter/material.dart';
import '../presentation/home/my_membership_page/membership_form_page_screen.dart';

class MembershipRequiredDialog extends StatelessWidget {
  final BuildContext context;
  final String message;

  const MembershipRequiredDialog({
    super.key,
    required this.context,
    this.message = 'Für den Zugriff auf diese Funktion ist eine Mitgliedschaft erforderlich.',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: const [
          Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text(
            'Mitgliedschaft erforderlich',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Abbrechen',
            style: TextStyle(
              color: Color.fromARGB(255, 121, 121, 121),
              fontSize: 16,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MembershipFormPageScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 179, 21, 21),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Mitgliedschaft erwerben',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
} 