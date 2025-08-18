import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/life_areas_service.dart';
import 'log_action_page.dart';
import 'navigation.dart';

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
    // TODO: Implement create new life area functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create new life area - coming soon')),
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
                        onPressed: _loadLifeAreas,
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
                                onTap: () => _selectLifeArea(area),
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
      case 'favorite':
        return Icons.favorite;
      case 'psychology':
        return Icons.psychology;
      case 'spa':
        return Icons.spa;
      case 'family_restroom':
        return Icons.family_restroom;
      default:
        return Icons.category;
    }
  }
}