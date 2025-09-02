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
            Text('Email: progresso.sup@gmail.com\n\nThis Privacy Policy explains how we collect, use, and protect your personal data when you use Progresso, in compliance with the EU General Data Protection Regulation (GDPR) and other applicable privacy laws.\n\nIMPORTANT: Progresso is a privacy-first app. By default, all your data is stored locally on your device and never transmitted to external servers. Cloud services and data sharing are entirely optional and require your explicit consent.'),
            SizedBox(height: 16),
            
            Text(
              '2. Data We Collect',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We collect the following categories of data:\n\n• Local Activity Data: Your logged activities, notes, progress tracking data, uploaded images (stored locally on your device)\n• Optional Account Information: Email address, username, profile information (only when you create a cloud account)\n• Usage Data: App interactions, feature usage, crash reports (anonymous, opt-in only)\n• Technical Data: Device information for app functionality (stored locally)\n• Optional AI Data: When enabled, summarized content for AI processing (with explicit consent)'),
            SizedBox(height: 16),
            
            Text(
              '3. How We Use Your Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We process your personal data for the following purposes:\n\n• Local App Functionality: Storing your progress data locally on your device, displaying statistics and insights\n• Optional Cloud Services: When you create an account, syncing data across your devices and managing your cloud account\n• Communication: Sending important service updates and responding to support requests (only for registered users)\n• Improvement: Analyzing anonymous usage patterns to improve app features (opt-in only)\n• AI Features: Processing your content with external AI services (only with explicit consent)'),
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
            Text('Data sharing depends on your usage:\n\n• Anonymous/Local Usage: No data sharing - all data stays on your device\n• Optional Cloud Account: Supabase (cloud database provider, EU/US regions, GDPR compliant) - only when you create an account\n• AI Providers: Only when AI features are enabled and with your explicit consent\n• Crash Reporting: Anonymous crash data (only if opted in)\n\nWe never sell your personal data to third parties. By default, your data never leaves your device.'),
            SizedBox(height: 16),
            
            Text(
              '6. Data Security',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('We implement appropriate security measures based on your usage:\n\n• Local Storage: Your data is encrypted and stored securely on your device using SQLite database\n• Cloud Storage (Optional): Encryption in transit (TLS/HTTPS) and at rest, secure data centers\n• Regular security updates and vulnerability assessments\n• Access controls and authentication requirements for cloud accounts\n• No third-party access to your local data'),
            SizedBox(height: 16),
            
            Text(
              '7. Data Retention',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Data retention varies by usage:\n\n• Local Data: Stored on your device until you delete the app or manually delete data\n• Cloud Account Data: Until you delete your cloud account (local data remains intact)\n• Anonymous Usage Data: Up to 2 years for service improvement (opt-in only)\n• AI Processing Data: Not retained after processing (temporary processing only)\n• You have full control over your local data at all times'),
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
            Text('International data transfers only occur when you explicitly enable certain features:\n\n• Local Usage: No international transfers - data stays on your device\n• Cloud Account: Data may be stored in EU/US regions with GDPR compliance\n• AI Features: When enabled, data may be sent to AI providers with Standard Contractual Clauses (SCCs)\n• All transfers are optional and require your explicit consent'),
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

