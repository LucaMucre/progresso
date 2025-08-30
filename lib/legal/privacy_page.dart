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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              'Effective Date: August 29, 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            
            Text(
              '1. Data Controller',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Email: progresso.sup@gmail.com\n\nThis Privacy Policy explains how we collect, use, and protect your personal data when you use Progresso, in compliance with the EU General Data Protection Regulation (GDPR) and other applicable privacy laws.'),
            SizedBox(height: 16),
            
            Text(
              '2. Data We Collect',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We collect the following categories of data:\n\n• Account Information: Email address, username, profile information\n• Activity Data: Your logged activities, notes, progress tracking data, uploaded images\n• Usage Data: App interactions, feature usage, crash reports (anonymous)\n• Technical Data: Device information, IP address, browser type (for web version)\n• Optional AI Data: When enabled, summarized content for AI processing'),
            SizedBox(height: 16),
            
            Text(
              '3. How We Use Your Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We process your personal data for the following purposes:\n\n• Service Provision: Creating and managing your account, storing your progress data\n• App Functionality: Displaying statistics, generating insights, syncing across devices\n• Communication: Sending important service updates and responding to support requests\n• Improvement: Analyzing usage patterns to improve app features (anonymized data)\n• AI Features: Processing your content with external AI services (only with explicit consent)'),
            SizedBox(height: 16),
            
            Text(
              '4. Legal Basis for Processing',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We process your data based on:\n\n• Contract Performance (Art. 6(1)(b) GDPR): To provide the core app services\n• Consent (Art. 6(1)(a) GDPR): For optional features like AI assistance and crash reporting\n• Legitimate Interest (Art. 6(1)(f) GDPR): For service improvement and security\n• Legal Obligation (Art. 6(1)(c) GDPR): For compliance with applicable laws'),
            SizedBox(height: 16),
            
            Text(
              '5. Data Sharing and Recipients',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We share your data with:\n\n• Supabase: Cloud database and authentication provider (EU/US regions, GDPR compliant)\n• AI Providers: Only when AI features are enabled and with your explicit consent\n• Crash Reporting: Anonymous crash data to Sentry (only if opted in)\n\nWe never sell your personal data to third parties.'),
            SizedBox(height: 16),
            
            Text(
              '6. Data Security',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We implement appropriate technical and organizational measures to protect your data:\n\n• Encryption in transit (TLS/HTTPS) and at rest\n• Regular security updates and vulnerability assessments\n• Access controls and authentication requirements\n• Secure data centers with physical and network security'),
            SizedBox(height: 16),
            
            Text(
              '7. Data Retention',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We retain your data:\n\n• Account Data: Until you delete your account\n• Activity Data: Until account deletion or manual deletion by user\n• Backup Data: Up to 90 days for disaster recovery\n• Anonymous Usage Data: Up to 2 years for service improvement\n• Legal Requirements: As required by applicable law'),
            SizedBox(height: 16),
            
            Text(
              '8. Your Rights Under GDPR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('You have the following rights:\n\n• Right of Access: Request a copy of your personal data\n• Right to Rectification: Correct inaccurate or incomplete data\n• Right to Erasure: Delete your data ("right to be forgotten")\n• Right to Restrict Processing: Limit how we process your data\n• Right to Data Portability: Export your data in a structured format\n• Right to Withdraw Consent: For processing based on consent\n• Right to Object: To processing based on legitimate interests\n• Right to Complain: To your local data protection authority'),
            SizedBox(height: 16),
            
            Text(
              '9. International Data Transfers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('When using AI features or certain cloud services, your data may be transferred to countries outside the EU. We ensure adequate protection through:\n\n• Standard Contractual Clauses (SCCs)\n• Adequacy decisions by the European Commission\n• Certification schemes and binding corporate rules'),
            SizedBox(height: 16),
            
            Text(
              '10. Children\'s Privacy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Progresso is not intended for children under 13 years of age. We do not knowingly collect personal data from children under 13. If you believe we have collected data from a child, please contact us immediately.'),
            SizedBox(height: 16),
            
            Text(
              '11. Cookies and Tracking',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We use minimal tracking technologies:\n\n• Essential Cookies: Required for app functionality and authentication\n• Local Storage: To store your preferences and offline data\n• Analytics: Anonymous usage statistics to improve the app (can be disabled)\n\nNo third-party advertising or tracking cookies are used.'),
            SizedBox(height: 16),
            
            Text(
              '12. Changes to Privacy Policy',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We may update this Privacy Policy to reflect changes in our practices or legal requirements. Significant changes will be communicated through the app or email with at least 30 days notice.'),
            SizedBox(height: 16),
            
            Text(
              '13. Contact Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('For privacy-related questions, data requests, or to exercise your rights, contact us at:\n\nEmail: progresso.sup@gmail.com\nSubject: Privacy Request\n\nWe will respond to your request within 30 days as required by GDPR.'),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

