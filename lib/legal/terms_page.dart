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
            Text('Progresso is a personal development application that allows you to track activities, log progress, manage life areas, and view personal statistics. The service may include optional AI-powered features that require explicit user consent.'),
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
            Text('You retain ownership of your content and data. By using Progresso, you grant us permission to store, process, and display your data as necessary to provide the service. You are responsible for backing up important data.'),
            SizedBox(height: 16),
            
            Text(
              '5. Privacy and Data Protection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Your privacy is important to us. Our data collection and processing practices are detailed in our Privacy Policy, which is incorporated by reference into these Terms. We comply with applicable data protection laws including GDPR.'),
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
            Text('The service is provided "as is" without warranties of any kind. We are not liable for data loss, service interruptions, or any indirect, incidental, or consequential damages. Our total liability is limited to the amount you paid for the service in the past 12 months.'),
            SizedBox(height: 16),
            
            Text(
              '9. Account Termination',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('You may delete your account at any time through the app settings. We may suspend or terminate accounts that violate these terms. Upon termination, your data will be deleted according to our data retention policies.'),
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

