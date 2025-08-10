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
            Text('Leistung: Progresso ermöglicht das Erfassen von Aktivitäten/Notizen und das Abrufen von Statistiken. Optionaler KI‑Assistenz‑Modus nach Opt‑in.'),
            SizedBox(height: 8),
            Text('Nutzung: Du bist für Inhalte verantwortlich; keine rechtswidrigen Inhalte.'),
            SizedBox(height: 8),
            Text('Kosten: aktuell kostenlos; Änderungen mit Vorankündigung.'),
            SizedBox(height: 8),
            Text('Haftung: App wird „wie besehen“ bereitgestellt; keine Gewähr für Verfügbarkeit/Fehlerfreiheit.'),
            SizedBox(height: 8),
            Text('Kündigung/Löschung: Konto kann jederzeit in der App gelöscht werden.'),
            SizedBox(height: 8),
            Text('Datenschutz: siehe Datenschutzerklärung.'),
          ],
        ),
      ),
    );
  }
}

