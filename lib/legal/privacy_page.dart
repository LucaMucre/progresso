import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: const [
            Text(
              'Privacy Policy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 12),
            Text('Controller: Luca Reckemeyer, Email: kontakt@example.com'),
            SizedBox(height: 12),
            Text('Purposes: Provide the app, account/auth management, store your activities and notes, optional AI assistance.'),
            SizedBox(height: 8),
            Text('Legal basis: Art. 6(1)(b) GDPR (contract), Art. 6(1)(a) (consent for AI assistance).'),
            SizedBox(height: 8),
            Text('Categories: Account data (email, name), content data (activity logs, notes), usage data.'),
            SizedBox(height: 8),
            Text('Retention: until account deletion or withdrawal; backups per legal retention periods.'),
            SizedBox(height: 8),
            Text('Recipients: Supabase (hosting, database, US/EU depending on region). External AI services are disabled in the current version (no personal data sent to third parties).'),
            SizedBox(height: 8),
            Text('Rights: access, rectification, erasure, restriction, data portability, withdrawal, complaint to the supervisory authority.'),
            SizedBox(height: 8),
            Text('Account deletion: directly in the app under Settings → Delete account.'),
            SizedBox(height: 8),
            Text('Data transfers: TLS/HTTPS; at‑rest encryption per Supabase.'),
          ],
        ),
      ),
    );
  }
}

