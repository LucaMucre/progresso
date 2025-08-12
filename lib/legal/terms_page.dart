import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Terms of Service',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 12),
            Text('Service: Progresso lets you capture activities/notes and view statistics. Optional AI assistance after opt-in.'),
            SizedBox(height: 8),
            Text('Use: You are responsible for your content; no unlawful content.'),
            SizedBox(height: 8),
            Text('Fees: currently free; changes may be announced in advance.'),
            SizedBox(height: 8),
            Text('Liability: App is provided “as is”; no warranty for availability or error-free operation.'),
            SizedBox(height: 8),
            Text('Termination/Deletion: You can delete your account anytime in the app.'),
            SizedBox(height: 8),
            Text('Privacy: see Privacy Policy.'),
          ],
        ),
      ),
    );
  }
}

