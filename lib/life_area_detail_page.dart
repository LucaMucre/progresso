import 'package:flutter/material.dart';
import 'services/life_areas_service.dart';
import 'services/db_service.dart';
import 'log_action_page.dart';

class LifeAreaDetailPage extends StatefulWidget {
  final LifeArea area;

  const LifeAreaDetailPage({
    Key? key,
    required this.area,
  }) : super(key: key);

  @override
  State<LifeAreaDetailPage> createState() => _LifeAreaDetailPageState();
}

class _LifeAreaDetailPageState extends State<LifeAreaDetailPage> {
  List<ActionTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await fetchTemplates();
      // Filter templates by category that matches the life area
      final filteredTemplates = templates.where((template) {
        return template.category.toLowerCase() == widget.area.category.toLowerCase() ||
               template.name.toLowerCase().contains(widget.area.name.toLowerCase());
      }).toList();
      
      setState(() {
        _templates = filteredTemplates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Fehler beim Laden der Templates: $e');
    }
  }

  void _logQuickAction() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogActionPage(
          selectedCategory: widget.area.category,
          selectedArea: widget.area.name,
        ),
      ),
    );
  }

  void _logTemplateAction(ActionTemplate template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogActionPage(
          template: template,
          selectedCategory: widget.area.category,
          selectedArea: widget.area.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area.name),
        backgroundColor: _parseColor(widget.area.color).withOpacity(0.1),
        foregroundColor: _parseColor(widget.area.color),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with area info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _parseColor(widget.area.color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _parseColor(widget.area.color).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _parseColor(widget.area.color),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(widget.area.icon),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.area.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _parseColor(widget.area.color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.area.category,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _parseColor(widget.area.color).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logQuickAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _parseColor(widget.area.color),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  'Schnell-Aktion für ${widget.area.name} loggen',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Templates Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vorlagen für ${widget.area.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_templates.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 48,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keine Vorlagen für ${widget.area.name}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Erstelle eine neue Vorlage oder nutze die Schnell-Aktion',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _parseColor(widget.area.color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(template.category),
                          color: _parseColor(widget.area.color),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        template.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${template.baseXp} XP • ${template.category}',
                        style: TextStyle(
                          color: Colors.grey.withOpacity(0.7),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: _parseColor(widget.area.color),
                        size: 16,
                      ),
                      onTap: () => _logTemplateAction(template),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'restaurant':
        return Icons.restaurant;
      case 'school':
        return Icons.school;
      case 'account_balance':
        return Icons.account_balance;
      case 'palette':
        return Icons.palette;
      case 'people':
        return Icons.people;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'work':
        return Icons.work;
      default:
        return Icons.circle;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'fitness':
        return Icons.fitness_center;
      case 'lernen':
      case 'learning':
        return Icons.school;
      case 'arbeit':
      case 'work':
        return Icons.work;
      case 'hobby':
        return Icons.sports_esports;
      case 'gesundheit':
      case 'health':
        return Icons.favorite;
      default:
        return Icons.star;
    }
  }
} 