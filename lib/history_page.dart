import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/db_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({Key? key}) : super(key: key);

  String _formatDate(DateTime dt) =>
    DateFormat('dd.MM.yyyy – HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Logs')),
      body: FutureBuilder<List<ActionLog>>(
        future: fetchLogs(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final logs = snap.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('Keine Einträge gefunden.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final log = logs[i];
              return ListTile(
                title: Text(
                  '${log.earnedXp} XP – ${_formatDate(log.occurredAt)}'
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.durationMin != null)
                      Text('Dauer: ${log.durationMin} Min'),
                    if (log.notes != null && log.notes!.isNotEmpty)
                      Text('Notiz: ${log.notes}'),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}