import 'package:flutter/material.dart';
import 'services/db_service.dart';

class LogActionPage extends StatefulWidget {
  final ActionTemplate? template;
  final String? selectedCategory;
  final String? selectedArea;
  
  const LogActionPage({
    Key? key, 
    this.template,
    this.selectedCategory,
    this.selectedArea,
  }) : super(key: key);

  @override
  State<LogActionPage> createState() => _LogActionPageState();
}

class _LogActionPageState extends State<LogActionPage> {
  final _durationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _activityNameCtrl = TextEditingController();
  bool _loading       = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill activity name if we have a template
    if (widget.template != null) {
      _activityNameCtrl.text = widget.template!.name;
    }
  }

  Future<void> _submitLog() async {
    // Validate inputs
    if (_activityNameCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Bitte gib einen Namen für die Aktivität ein.'; });
      return;
    }

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
      ActionLog log;
      
      if (widget.template != null) {
        // Use existing template
        log = await createLog(
          templateId : widget.template!.id,
          durationMin: duration,
          notes      : _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        // Create a quick log without template
        final activityName = _activityNameCtrl.text.trim();
        final notes = _notesCtrl.text.trim();
        final areaName = widget.selectedArea ?? '';
        final category = widget.selectedCategory ?? 'Allgemein';
        
        // Combine activity name, area, and notes for better filtering
        final combinedNotes = notes.isEmpty 
          ? '$activityName ($areaName)' 
          : '$activityName ($areaName): $notes';
        
        log = await createQuickLog(
          activityName: activityName,
          category: category,
          durationMin: duration,
          notes: combinedNotes,
        );
      }
      
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
    _activityNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tpl = widget.template;
    final title = tpl != null ? 'Log: ${tpl.name}' : 'Neue Aktion loggen';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Activity name field (only show if no template)
            if (widget.template == null) ...[
              Text('Aktivitätsname:', style: Theme.of(context).textTheme.bodyMedium),
              TextField(
                controller: _activityNameCtrl,
                decoration: const InputDecoration(
                  hintText: 'z. B. Laufen, Lesen, Meditation...',
                ),
              ),
              const SizedBox(height: 16),
            ],
            
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