import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js_interop' if (dart.library.html) 'dart:js_interop';
import 'utils/app_theme.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  // On web, ask the browser to show the password-save prompt immediately
  void _promptSavePasswordNow(String email, String password) {
    if (!kIsWeb) return;
    try {
      // Use js_interop for modern web integration
      if (kIsWeb) {
        // Call JavaScript functions if available
        // js.context.callMethod('triggerImmediatePasswordSavePrompt', [email, password]);
        // js.context.callMethod('storePasswordCredential', [email, password]);
        // TODO: Migrate to dart:js_interop when web-specific functionality is needed
      }
    } catch (_) {}
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }
    try {
      // Magic-Link zum Passwort-Reset in der App. Der Link führt zurück in die App,
      // onAuthStateChange liefert dann USER_UPDATED, worauf wir einen Dialog zeigen.
      final origin = Uri.base.origin; // funktioniert für Web & Desktop (http://localhost:...)
      await Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: origin);
      if (!mounted) return;
      // Kurzer Hinweis-Dialog statt nur Snackbar
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Email sent'),
          content: Text('We sent a reset link to "$email".'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      if (email.isEmpty || pass.isEmpty) {
        setState(() {
          _error = 'Please enter email and password.';
        });
        return;
      }
      if (_isLogin) {
        // Echter Login mit Supabase
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        if (res.session != null) {
          // Trigger save-password prompt now so it won't appear later
          _promptSavePasswordNow(email, pass);
          // Successfully logged in → AuthGate will navigate to dashboard
          return;
        } else {
          setState(() {
            _error = 'Login failed. Please check email & password.';
          });
        }
      } else {
        // Echte Registrierung mit Supabase
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: pass,
        );
        if (res.user != null) {
          // Registration succeeded
          setState(() {
            _error = 'Registration successful! Please log in now.';
            _isLogin = true;
          });
        } else {
          setState(() {
            _error = 'Registration failed. Please try again.';
          });
        }
      }
    } on AuthException catch (err) {
      setState(() {
        final msg = (err.message.trim().isEmpty)
            ? (_isLogin
                ? 'Login failed. Please check your credentials or confirm your email.'
                : 'Sign up failed. Please try again.')
            : err.message;
        _error = msg;
      });
    } catch (err) {
      setState(() {
        _error = err.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 980;

    Widget buildHero() {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated floating elements
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Main headline with better typography
            RichText(
              text: TextSpan(
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.2,
                ),
                children: [
                  TextSpan(
                    text: 'Track.\n',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                  TextSpan(
                    text: 'Grow.\n',
                    style: TextStyle(color: AppTheme.successColor),
                  ),
                  TextSpan(
                    text: 'Succeed.',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text(
              'Build habits that stick. See your progress.\nAchieve your goals.',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildAuthCard() {
      return Container(
        constraints: const BoxConstraints(maxWidth: 400),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simple header
            Text(
              _isLogin ? '👋 Welcome back!' : '🚀 Let\'s get started',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin 
                ? 'Good to see you again'
                : 'Create your account in seconds',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            
            // Simplified form fields
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: InputDecoration(
                      hintText: 'Your email',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  
                  Container(
                    height: 1,
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Error display (simplified)
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Main action button
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLogin 
                    ? [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)]
                    : [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_isLogin ? AppTheme.primaryColor : AppTheme.successColor)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Sign in' : 'Create account',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Switch mode and forgot password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _error = null;
                    });
                  },
                  child: Text(
                    _isLogin ? 'Create account' : 'Sign in instead',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_isLogin)
                  TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Background with subtle gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerLow,
                  colorScheme.surfaceContainer,
                ],
              ),
            ),
          ),
          
          // Floating decorative elements
          Positioned(
            top: 100,
            right: 80,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(60),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          
          // Content
          Container(
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: buildHero()),
                        const SizedBox(width: 32),
                        Expanded(child: buildAuthCard()),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildHero(),
                        const SizedBox(height: 40),
                        buildAuthCard(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}