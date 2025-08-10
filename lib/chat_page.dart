import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(role: 'user', content: text));
    });
    _inputCtrl.clear();

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'chat',
        body: {'query': text},
      );
      // The Functions client returns dynamic; we expect a Map
      final data = (res.data is Map)
          ? res.data as Map
          : jsonDecode(res.data as String) as Map<String, dynamic>;
      final answer = (data['answer'] as String?) ?? 'Keine Antwort erhalten.';
      final List sources = (data['sources'] as List?) ?? [];
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: answer,
            sources: sources
                .map((e) => _Source(
                      id: (e['id'] ?? '').toString(),
                      title: (e['title'] ?? '').toString(),
                      occurredAt: (e['occurred_at'] ?? '').toString(),
                    ))
                .toList(),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: 'Fehler: $e',
          ),
        );
      });
    } finally {
      setState(() => _sending = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _reindex() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ingest',
        body: {'since': null},
      );
      final data = (res.data is Map)
          ? res.data as Map
          : jsonDecode(res.data as String) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Index aktualisiert: ${data['logs']} Logs, ${data['chunks']} Chunks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Reindex: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Index neu aufbauen',
            icon: const Icon(Icons.refresh),
            onPressed: _sending ? null : _reindex,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m.role == 'user';
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                        : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: isUser ? TextAlign.right : TextAlign.left,
                      ),
                      if (m.sources.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: m.sources
                              .map<Widget>((s) => Tooltip(
                                    message: s.occurredAt,
                                    child: Chip(
                                      label: Text(
                                        s.title.isEmpty ? 'Quelle' : s.title,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Frage zu deinen Daten…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Senden'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<_Source> sources;
  _ChatMessage({required this.role, required this.content, List<_Source>? sources})
      : sources = sources ?? const [];
}

class _Source {
  final String id;
  final String title;
  final String occurredAt;
  const _Source({required this.id, required this.title, required this.occurredAt});
}

