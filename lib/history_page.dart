import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/db_service.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;

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
          if (snap.connectionState == ConnectionState.waiting) {
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
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final log = logs[i];
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${log.earnedXp} XP',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(log.occurredAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (log.durationMin != null) ...[
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${log.durationMin} Minuten',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Optional: Bereich/Kategorie Chip wenn in Notes vorhanden
                      ..._buildAreaCategoryChip(log.notes, context),
                      if (log.notes != null && log.notes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                      ],
                      if (log.notes != null && log.notes!.isNotEmpty) ...[
                        _renderNotes(log.notes!, context),
                        const SizedBox(height: 12),
                      ],
                      if (log.imageUrl != null) ...[
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              log.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 48,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _renderNotes(String value, BuildContext context) {
    try {
      final dynamic parsed = jsonDecode(value);
      if (parsed is Map<String, dynamic>) {
        final delta = parsed['delta'];
        if (delta is List) {
          final doc = quill.Document.fromJson(delta);
          final controller = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
          return SizedBox(
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.all(8),
              child: quill.QuillEditor.basic(
                controller: controller,
                config: const quill.QuillEditorConfig(
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          );
        }
      } else if (parsed is List) {
        final doc = quill.Document.fromJson(parsed);
        final controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        return SizedBox(
          height: 180,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(8),
            child: quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        );
      }
    } catch (_) {}
    return Text(value, style: Theme.of(context).textTheme.bodyMedium);
  }

  List<Widget> _buildAreaCategoryChip(String? value, BuildContext context) {
    if (value == null || value.isEmpty) return const [];
    try {
      final parsed = jsonDecode(value);
      if (parsed is Map<String, dynamic>) {
        final area = parsed['area'] as String?;
        final category = parsed['category'] as String?;
        if (area != null || category != null) {
          final label = area != null && category != null
              ? '$area – $category'
              : (area ?? category!);
          return [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.label, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Colors.blue)),
                ],
              ),
            )
          ];
        }
      }
    } catch (_) {}
    return const [];
  }
}