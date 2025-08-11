import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'legal/privacy_page.dart';
import 'legal/terms_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _assistOptIn = false;
  bool _loading = true;
  final _newPwCtrl = TextEditingController();
  final _newPw2Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // KI-Assistenz für alle Nutzer deaktivieren (Datenschutz: keine externen Aufrufe)
    await prefs.setBool('assist_opt_in', false);
    setState(() {
      _assistOptIn = false;
      _loading = false;
    });
  }

  Future<void> _changePassword() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Passwort ändern'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newPwCtrl,
                  decoration: const InputDecoration(labelText: 'Neues Passwort'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPw2Ctrl,
                  decoration: const InputDecoration(labelText: 'Neues Passwort (wiederholen)'),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final newPw = _newPwCtrl.text.trim();
                final newPw2 = _newPw2Ctrl.text.trim();
                if (newPw.isEmpty || newPw2.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte neues Passwort eingeben')));
                  return;
                }
                if (newPw != newPw2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwörter stimmen nicht überein')));
                  return;
                }
                try {
                  // Hinweis: Supabase benötigt das alte Passwort hier nicht, der Nutzer muss eingeloggt sein
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPw));
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwort aktualisiert')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    _newPwCtrl.clear();
    _newPw2Ctrl.clear();
  }

  Future<void> _toggleAssist(bool enable) async {
    if (enable) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('KI‑Assistenz aktivieren?'),
          content: const Text(
              'Wenn du den KI‑Assistenz‑Modus aktivierst, können Anfragen mit zusammengefassten Inhalten an einen externen KI‑Dienst gesendet werden. Deine Daten werden weiterhin durch RLS auf deinen Account beschränkt. Du kannst den Modus jederzeit wieder deaktivieren.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aktivieren')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('assist_opt_in', enable);
    setState(() => _assistOptIn = enable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('KI‑Assistenz ist nun ${enable ? 'aktiv' : 'deaktiviert'}')),
    );
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konto wirklich löschen?'),
        content: const Text(
            'Dies löscht deinen Account und alle zugehörigen Daten dauerhaft. Dieser Vorgang kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Endgültig löschen')),
        ],
      ),
    );
    if (ok != true) return;

    // 1) Serverseitig löschen
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'delete-account',
        body: {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konto gelöscht: ${res.data ?? 'ok'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Löschen: $e')),
      );
      // trotzdem lokal abmelden versuchen
    }
    // 2) Lokale Session beenden; 403 nach Server-Delete ignorieren
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // KI-Assistenz-Option entfernt (immer aus)
                const SizedBox.shrink(),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Passwort ändern'),
                  onTap: _changePassword,
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Datenschutz'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Nutzungsbedingungen'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsPage()),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Konto löschen'),
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }
}

