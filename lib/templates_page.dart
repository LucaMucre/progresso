import 'package:flutter/material.dart';
import 'services/db_service.dart';
import 'log_action_page.dart';

class TemplatesList extends StatefulWidget {
  const TemplatesList({Key? key}) : super(key: key);

  @override
  State<TemplatesList> createState() => _TemplatesListState();
}

class _TemplatesListState extends State<TemplatesList> {
  late Future<List<ActionTemplate>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActionTemplate>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Fehler: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final templates = snapshot.data!;
        if (templates.isEmpty) {
          return const Center(child: Text('Keine Templates gefunden.'));
        }
        return ListView.builder(
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final tpl = templates[index];
            return ListTile(
              title: Text(tpl.name),
              subtitle: Text('Kategorie: ${tpl.category} · XP: ${tpl.baseXp}'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LogActionPage(template: tpl),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}