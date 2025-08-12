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

  Widget _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return const Icon(Icons.fitness_center, color: Colors.red);
      case 'lernen':
      case 'learning':
        return const Icon(Icons.school, color: Colors.blue);
      case 'arbeit':
      case 'work':
        return const Icon(Icons.work, color: Colors.orange);
      case 'hobby':
        return const Icon(Icons.sports_esports, color: Colors.green);
      case 'gesundheit':
      case 'health':
        return const Icon(Icons.favorite, color: Colors.pink);
      default:
        return const Icon(Icons.star, color: Colors.purple);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Colors.red.withOpacity(0.1);
      case 'lernen':
      case 'learning':
        return Colors.blue.withOpacity(0.1);
      case 'arbeit':
      case 'work':
        return Colors.orange.withOpacity(0.1);
      case 'hobby':
        return Colors.green.withOpacity(0.1);
      case 'gesundheit':
      case 'health':
        return Colors.pink.withOpacity(0.1);
      default:
        return Colors.purple.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActionTemplate>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
    'Error loading',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final templates = snapshot.data!;
        
        if (templates.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.add_task,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Actions gefunden',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erstelle deine erste Action um zu starten!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final template = templates[index];
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LogActionPage(template: template),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(template.category),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _getCategoryIcon(template.category),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                template.category,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                '${template.baseXp} XP',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}