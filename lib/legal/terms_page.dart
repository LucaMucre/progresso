import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutzungsbedingungen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Nutzungsbedingungen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              'Dies ist ein Platzhalter. Bitte ergänze hier deine vollständigen AGB/Nutzungsbedingungen. '
              'Beschreibe die Leistungen, Rechte und Pflichten, Haftungsausschlüsse etc.',
            ),
          ],
        ),
      ),
    );
  }
}

