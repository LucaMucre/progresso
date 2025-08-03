import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Einloggen' : 'Registrieren'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'E-Mail'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Passwort'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isLogin ? 'Einloggen' : 'Registrieren'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _error = null;
                });
              },
              child: Text(_isLogin
                  ? 'Noch kein Konto? Registrieren'
                  : 'Bereits ein Konto? Einloggen'),
            ),
          ],
        ),
      ),
    );
  }
}