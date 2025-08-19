import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/life_areas_service.dart';
import 'log_action_page.dart';
import 'navigation.dart';
import 'utils/haptic_utils.dart';

class LifeAreaSelectionPage extends StatefulWidget {
  const LifeAreaSelectionPage({Key? key}) : super(key: key);

  @override
  State<LifeAreaSelectionPage> createState() => _LifeAreaSelectionPageState();
}

class _LifeAreaSelectionPageState extends State<LifeAreaSelectionPage> {
  List<LifeArea> _lifeAreas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLifeAreas();
  }

  Future<void> _loadLifeAreas() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      final areas = await LifeAreasService.getLifeAreas();
      
      // If no life areas exist, create default ones
      if (areas.isEmpty) {
        await LifeAreasService.createDefaultLifeAreas();
        final newAreas = await LifeAreasService.getLifeAreas();
        setState(() {
          _lifeAreas = newAreas;
          _loading = false;
        });
      } else {
        setState(() {
          _lifeAreas = areas;
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading life areas: $e');
      setState(() {
        _error = 'Error loading life areas';
        _loading = false;
      });
    }
  }

  void _selectLifeArea(LifeArea area) {
    // Show as modal bottom sheet instead of replacing route
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: LogActionPage(
            selectedArea: area.name,
            selectedCategory: area.category,
            areaColorHex: area.color,
            areaIcon: area.icon,
            scrollController: scrollController,
            isModal: true,
          ),
        ),
      ),
    );
  }

  void _createNewArea() {
    _showCreateAreaDialog();
  }

  void _showCreateAreaDialog() {
    final nameController = TextEditingController();
    String selectedCategory = 'Work';
    String selectedColor = '#2196F3';
    String selectedIcon = 'circle';

    final categories = ['Work', 'Health', 'Social', 'Creativity', 'Finance', 'Learning', 'Inner'];
    final colors = [
      '#2196F3', '#FF5722', '#4CAF50', '#FF9800', 
      '#9C27B0', '#F44336', '#795548', '#607D8B'
    ];
    final icons = [
      'circle', 'work', 'fitness_center', 'favorite', 
      'school', 'attach_money', 'self_improvement', 'art_track'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Life Area'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter life area name',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (value) => setState(() => selectedCategory = value!),
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: colors.map((color) => GestureDetector(
                    onTap: () => setState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                        shape: BoxShape.circle,
                        border: selectedColor == color 
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Icon:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: icons.map((iconName) => GestureDetector(
                    onTap: () => setState(() => selectedIcon = iconName),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selectedIcon == iconName 
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: selectedIcon == iconName 
                          ? Border.all(color: Theme.of(context).colorScheme.primary)
                          : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      child: Icon(_getIconData(iconName)),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }

                try {
                  await LifeAreasService.createLifeArea(
                    name: nameController.text.trim(),
                    category: selectedCategory,
                    color: selectedColor,
                    icon: selectedIcon,
                    orderIndex: _lifeAreas.length,
                  );
                  
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _loadLifeAreas(); // Refresh the list
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Life area created successfully!')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating life area: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Life Area'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_error!, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          HapticUtils.submit();
                          _loadLifeAreas();
                        },
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.category,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose a Life Area',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'For which area of your life would you like to log an activity?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Life areas grid
                      if (_lifeAreas.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _lifeAreas.length,
                          itemBuilder: (context, index) {
                            final area = _lifeAreas[index];
                            final name = area.name;
                            final category = area.category;
                            final colorHex = area.color;
                            final iconName = area.icon;
                            
                            final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));
                            final icon = _getIconData(iconName);
                            
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticUtils.selectionClick();
                                  _selectLifeArea(area);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 32,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (category.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            category,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        // Empty state
                        Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No life areas found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first life area to log activities.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Create new area button
                      OutlinedButton.icon(
                        onPressed: _createNewArea,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Life Area'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'work': return Icons.work;
      case 'fitness_center': return Icons.fitness_center;
      case 'favorite': return Icons.favorite;
      case 'school': return Icons.school;
      case 'attach_money': return Icons.attach_money;
      case 'self_improvement': return Icons.self_improvement;
      case 'art_track': return Icons.art_track;
      case 'restaurant': return Icons.restaurant;
      case 'psychology': return Icons.psychology;
      case 'spa': return Icons.spa;
      case 'family_restroom': return Icons.family_restroom;
      case 'palette': return Icons.palette;
      case 'people': return Icons.people;
      case 'account_balance': return Icons.account_balance;
      default: return Icons.circle;
    }
  }
}