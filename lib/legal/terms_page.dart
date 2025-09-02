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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              'Effective Date: August 29, 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            
            Text(
              '1. Service Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Progresso is a privacy-first personal development application that allows you to track activities, log progress, manage life areas, and view personal statistics. By default, all data is stored locally on your device. The service may include optional cloud synchronization and AI-powered features that require explicit user consent.'),
            SizedBox(height: 16),
            
            Text(
              '2. User Responsibilities',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('You agree to:\n• Provide accurate information when creating your account\n• Use the service lawfully and not upload illegal, harmful, or offensive content\n• Respect intellectual property rights\n• Not attempt to reverse engineer, hack, or disrupt the service\n• Keep your login credentials secure'),
            SizedBox(height: 16),
            
            Text(
              '3. Service Availability',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We strive to maintain service availability but do not guarantee uninterrupted access. We may perform maintenance, updates, or modifications that temporarily affect service availability. We reserve the right to modify or discontinue features with reasonable notice.'),
            SizedBox(height: 16),
            
            Text(
              '4. Content and Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('You retain full ownership of your content and data. When using Progresso locally, your data never leaves your device. When using optional cloud features, you grant us permission to store, process, and display your data as necessary to provide cloud synchronization. You are responsible for backing up important data.'),
            SizedBox(height: 16),
            
            Text(
              '5. Privacy and Data Protection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Your privacy is our top priority. Progresso is designed as a local-first application - your data stays on your device by default. Our data collection and processing practices for optional cloud features are detailed in our Privacy Policy, which is incorporated by reference into these Terms. We comply with applicable data protection laws including GDPR.'),
            SizedBox(height: 16),
            
            Text(
              '6. AI Features and Third-Party Services',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Optional AI features require separate consent and may involve third-party AI services. When enabled, summarized content may be sent to external AI providers. You can disable these features at any time in your settings.'),
            SizedBox(height: 16),
            
            Text(
              '7. Pricing and Payment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Progresso is currently offered free of charge. We reserve the right to introduce paid features or subscription plans in the future with at least 30 days advance notice to existing users.'),
            SizedBox(height: 16),
            
            Text(
              '8. Limitation of Liability',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('The service is provided "as is" without warranties of any kind. For local usage, you are responsible for your device security and data backups. For optional cloud services, we are not liable for data loss, service interruptions, or any indirect, incidental, or consequential damages. Our total liability is limited to the amount you paid for the service in the past 12 months.'),
            SizedBox(height: 16),
            
            Text(
              '9. Account Termination',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('You may delete your cloud account at any time through the app settings. Local data remains on your device even after cloud account deletion. We may suspend or terminate cloud accounts that violate these terms. Upon cloud account termination, your cloud data will be deleted according to our data retention policies, but your local data remains intact.'),
            SizedBox(height: 16),
            
            Text(
              '10. Changes to Terms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We may update these Terms of Service. Significant changes will be communicated through the app or email. Continued use after changes constitutes acceptance of the updated terms.'),
            SizedBox(height: 16),
            
            Text(
              '11. Governing Law and Disputes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('These terms are governed by German law. For EU consumers, mandatory consumer protection laws of your country of residence may also apply. Disputes will be resolved through German courts or alternative dispute resolution where applicable.'),
            SizedBox(height: 16),
            
            Text(
              '12. Contact',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('For questions about these Terms of Service, contact us at:\nprogresso.sup@gmail.com'),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

