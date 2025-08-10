import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenschutz')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Datenschutzerklärung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              'Dies ist ein Platzhalter. Bitte ergänze hier deine vollständige Datenschutzerklärung, '
              'inklusive Angaben zu Kategorien verarbeiteter Daten, Aufbewahrungsdauer, '
              'Rechtsgrundlagen und Kontaktinformationen. Verlinke diese Seite im App‑Store‑Eintrag.',
            ),
          ],
        ),
      ),
    );
  }
}

