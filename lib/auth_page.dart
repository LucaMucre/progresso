import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte E‑Mail eingeben')));
      return;
    }
    try {
      // Magic-Link zum Passwort-Reset in der App. Der Link führt zurück in die App,
      // onAuthStateChange liefert dann USER_UPDATED, worauf wir einen Dialog zeigen.
      final origin = Uri.base.origin; // funktioniert für Web & Desktop (http://localhost:...)
      await Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: origin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort‑Reset E‑Mail versendet.')));
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
      if (_isLogin) {
        // Echter Login mit Supabase
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: pass,
        );
        if (res.session != null) {
          // Erfolgreich eingeloggt → AuthGate wechselt automatisch ins Dashboard
          return;
        } else {
          setState(() {
            _error = 'Login fehlgeschlagen. Bitte prüfe E-Mail & Passwort.';
          });
        }
      } else {
        // Echte Registrierung mit Supabase
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: pass,
        );
        if (res.user != null) {
          // Registrierung hat geklappt
          setState(() {
            _error = 'Registrierung erfolgreich! Bitte jetzt einloggen.';
            _isLogin = true;
          });
        } else {
          setState(() {
            _error = 'Registrierung fehlgeschlagen. Bitte erneut versuchen.';
          });
        }
      }
    } on AuthException catch (err) {
      setState(() {
        _error = err.message;
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
    final isWide = MediaQuery.of(context).size.width >= 980;

    Widget buildHero() {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.rocket_launch, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text('Willkommen bei Progresso', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF64B5F6), Color(0xFF69F0AE)],
              ).createShader(rect),
              child: const Text(
                'Bring deine Gewohnheiten\nauf Erfolgskurs',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Verstehe was dich voranbringt. Tracke Aktivitäten,\n' 
              'erhalte Einsichten und baue konsistente Routinen auf.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white.withOpacity(0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    backgroundColor: const Color(0xFF64B5F6),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: _loading
                      ? null
                      : () {
                          if (_isLogin) {
                            setState(() => _isLogin = false);
                          } else {
                            _submit();
                          }
                        },
                  label: Text(_isLogin ? 'Kostenlos starten' : 'Jetzt registrieren'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _isLogin = true),
                  child: const Text('Ich habe bereits ein Konto'),
                ),
              ],
            )
          ],
        ),
      );
    }

    Widget buildAuthCard() {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    offset: const Offset(0, 20),
                    blurRadius: 50,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: _isLogin ? const Color(0xFF64B5F6) : const Color(0xFF69F0AE),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isLogin ? 'Welcome back' : 'Create your account',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text('Passwort vergessen?', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Melde dich mit deiner E-Mail an'
                        : 'Registriere dich mit E-Mail & Passwort',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                      hintText: 'E-Mail',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF64B5F6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                      hintText: 'Passwort',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF64B5F6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF69F0AE),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLogin ? 'Einloggen' : 'Registrieren',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? 'Noch kein Konto? Jetzt registrieren'
                          : 'Bereits ein Konto? Zum Login',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF0B1020), Color(0xFF0A0F1D)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: buildHero()),
                    const SizedBox(width: 12),
                    SizedBox(width: 520, child: buildAuthCard()),
                  ],
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHero(),
                    const SizedBox(height: 16),
                    buildAuthCard(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}