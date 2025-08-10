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
            Text('Verantwortlicher: Luca Reckemeyer, E‑Mail: kontakt@example.com'),
            SizedBox(height: 12),
            Text('Zwecke: Bereitstellung der App, Konto‑/Authentifizierungsverwaltung, Speicherung deiner Aktivitäten und Notizen, optionale KI‑Assistenz.'),
            SizedBox(height: 8),
            Text('Rechtsgrundlagen: Art. 6 Abs. 1 lit. b DSGVO (Vertrag), lit. a (Einwilligung für KI‑Assistenz).'),
            SizedBox(height: 8),
            Text('Kategorien: Accountdaten (E‑Mail, Name), Inhaltsdaten (Aktivitätslogs, Notizen), Nutzungsdaten.'),
            SizedBox(height: 8),
            Text('Speicherdauer: bis zur Kontolöschung oder Widerruf; Backups gem. gesetzlichen Fristen.'),
            SizedBox(height: 8),
            Text('Empfänger: Supabase (Hosting, Datenbank, USA/EU je nach Region). Externe KI nur bei Opt‑in; Inhalte werden aggregiert/gekürzt übermittelt.'),
            SizedBox(height: 8),
            Text('Rechte: Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerruf, Beschwerde bei der Aufsichtsbehörde.'),
            SizedBox(height: 8),
            Text('Account‑Löschung: direkt in der App unter Einstellungen → Konto löschen.'),
            SizedBox(height: 8),
            Text('Datentransfers: TLS/HTTPS; Verschlüsselung at‑rest gemäß Supabase.'),
          ],
        ),
      ),
    );
  }
}

