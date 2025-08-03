import 'package:flutter/material.dart';
import 'services/db_service.dart';

class LogActionPage extends StatefulWidget {
  final ActionTemplate template;
  const LogActionPage({Key? key, required this.template}) : super(key: key);

  @override
  State<LogActionPage> createState() => _LogActionPageState();
}

class _LogActionPageState extends State<LogActionPage> {
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  bool _loading       = false;
  String? _error;

  Future<void> _submitLog() async {
    final raw = _durationCtrl.text.trim();
    int? duration;
    if (raw.isNotEmpty) {
      duration = int.tryParse(raw);
      if (duration == null) {
        setState(() { _error = 'Bitte eine gültige Zahl für Minuten eingeben.'; });
        return;
      }
    }
    setState(() { _loading = true; _error = null; });

    try {
      final log = await createLog(
        templateId : widget.template.id,
        durationMin: duration,
        notes      : _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      // Auf Erfolg hinweisen und zurück zur Liste
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Log angelegt: +${log.earnedXp} XP')),
      );
      Navigator.of(context).pop();  // zurück
    } catch (err) {
      setState(() { _error = 'Fehler beim Speichern: $err'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tpl = widget.template;
    return Scaffold(
      appBar: AppBar(
        title: Text('Log: ${tpl.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dauer in Minuten (optional):', style: Theme.of(context).textTheme.bodyMedium),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'z. B. 45'),
            ),
            const SizedBox(height: 16),
            Text('Notiz (optional):', style: Theme.of(context).textTheme.bodyMedium),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Deine Gedanken…'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ElevatedButton(
              onPressed: _loading ? null : _submitLog,
              child: _loading
                ? const SizedBox(
                    height: 16, width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Log speichern'),
            ),
          ],
        ),
      ),
    );
  }
}