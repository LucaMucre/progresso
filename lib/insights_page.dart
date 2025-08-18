import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/action_models.dart';
import 'services/life_areas_service.dart';
import 'widgets/activity_details_dialog.dart';
import 'utils/app_theme.dart';
import 'utils/logging_service.dart';
import 'utils/parsed_activity_data.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _filteredActivities = [];
  List<LifeArea> _lifeAreas = [];
  
  bool _isLoading = false;
  String? _selectedLifeArea;
  DateTimeRange? _selectedDateRange;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_performSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load life areas for filter
      final lifeAreas = await LifeAreasService.getLifeAreas();
      
      // Load all activities with notes or detailed titles
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('action_logs')
          .select('''
            id,
            notes,
            duration_min,
            earned_xp,
            occurred_at,
            template_id,
            image_url,
            action_templates (
              name,
              category
            )
          ''')
          .eq('user_id', userId)
          .order('occurred_at', ascending: false);

      setState(() {
        _lifeAreas = lifeAreas;
        _activities = List<Map<String, dynamic>>.from(response);
        _filteredActivities = _activities;
        _isLoading = false;
      });
    } catch (e) {
      LoggingService.error('Error loading insights data', e);
      setState(() => _isLoading = false);
    }
  }

  void _performSearch() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredActivities = _activities.where((activity) {
        // Parse notes data to get meaningful content
        final notesData = _parseNotesData(activity['notes']);
        
        // Text search in title and notes
        bool matchesText = true;
        if (query.isNotEmpty) {
          final templateName = (activity['action_templates']?['name'] ?? '').toString().toLowerCase();
          final notesTitle = notesData['title'].toString().toLowerCase();
          final notesText = notesData['plainText'].toString().toLowerCase();
          
          // Split query into words for partial matching
          final queryWords = query.split(' ').where((word) => word.isNotEmpty);
          
          matchesText = queryWords.every((word) =>
            templateName.contains(word) || 
            notesTitle.contains(word) ||
            notesText.contains(word)
          );
        }
        
        // Life area filter
        bool matchesLifeArea = true;
        if (_selectedLifeArea != null && _selectedLifeArea!.isNotEmpty) {
          matchesLifeArea = _activityMatchesLifeArea(activity, _selectedLifeArea!);
        }
        
        // Date filter
        bool matchesDate = true;
        if (_selectedDateRange != null) {
          final activityDateTime = DateTime.parse(activity['occurred_at']);
          // Convert to date only (ignore time) for comparison
          final activityDate = DateTime(activityDateTime.year, activityDateTime.month, activityDateTime.day);
          final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
          final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
          
          // Check if activity date is within the selected range (inclusive)
          matchesDate = !activityDate.isBefore(startDate) && !activityDate.isAfter(endDate);
        }
        
        return matchesText && matchesLifeArea && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _performSearch();
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
    });
    _performSearch();
  }

  void _clearLifeAreaFilter() {
    setState(() {
      _selectedLifeArea = null;
    });
    _performSearch();
  }

  // Helper method to check if an activity matches a selected life area
  bool _activityMatchesLifeArea(Map<String, dynamic> activity, String selectedAreaName) {
    final notesData = _parseNotesData(activity['notes']);
    final notesCategory = notesData['category'].toString();
    final templateCategory = activity['action_templates']?['category'] ?? '';
    final categoryToCheck = notesCategory.isNotEmpty ? notesCategory : templateCategory;
    
    // Direct match with category name
    if (categoryToCheck == selectedAreaName) {
      return true;
    }
    
    // Find the selected life area and check if its category matches
    for (final area in _lifeAreas) {
      if (area.name == selectedAreaName) {
        // Check if the activity's category matches this area's category or name
        return area.category.toLowerCase() == categoryToCheck.toLowerCase() ||
               area.name.toLowerCase() == categoryToCheck.toLowerCase();
      }
    }
    
    return false;
  }

  // Helper method to parse color strings safely
  Color _parseColor(String colorString) {
    try {
      String colorHex = colorString;
      // Handle different hex color formats
      if (colorHex.startsWith('#')) {
        colorHex = colorHex.substring(1);
      }
      if (colorHex.length == 6) {
        colorHex = 'FF$colorHex'; // Add alpha if missing
      }
      return Color(int.parse(colorHex, radix: 16));
    } catch (e) {
      return AppTheme.primaryColor; // Fallback color
    }
  }

  // Helper method to format dates in a user-friendly way
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);
    
    if (activityDate == today) {
      return 'Today';
    } else if (activityDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      // Show day of week for recent dates
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else if (date.year == now.year) {
      // Same year, show month and day
      return '${date.day}/${date.month}';
    } else {
      // Different year, show full date
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Helper method to parse notes JSON and extract meaningful data
  Map<String, dynamic> _parseNotesData(String? notesJson) {
    final parsed = ParsedActivityData.fromNotes(notesJson);
    return {
      'title': parsed.title ?? '',
      'area': parsed.area ?? '',
      'category': parsed.category ?? '',
      'plainText': parsed.plainText ?? '',
    };
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    // Convert the map to ActionLog format for compatibility
    final actionLog = ActionLog(
      id: activity['id'],
      occurredAt: DateTime.parse(activity['occurred_at']),
      durationMin: activity['duration_min'],
      notes: activity['notes'],
      earnedXp: activity['earned_xp'] ?? 0,
      templateId: activity['template_id'],
      activityName: null, // This field doesn't exist in action_logs table
      imageUrl: activity['image_url'],
    );
    
    showDialog(
      context: context,
      builder: (context) => ActivityDetailsDialog(
        log: actionLog,
        onUpdate: () {
          // Reload data after editing
          _loadInitialData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('💡 Insights'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search in titles and notes...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Filters
                Row(
                  children: [
                    // Life area filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedLifeArea,
                            hint: const Text('All areas'),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: const Text('All life areas'),
                              ),
                              ..._lifeAreas.map((area) => DropdownMenuItem<String?>(
                                value: area.name, // Filter by category name which matches the area name
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _parseColor(area.color),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(area.name),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedLifeArea = value;
                              });
                              _performSearch();
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Date range filter
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, 
                                size: 18, 
                                color: colorScheme.onSurface.withValues(alpha: 0.6)
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedDateRange == null
                                      ? 'All time'
                                      : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Active filters display
                if (_selectedLifeArea != null || _selectedDateRange != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_selectedLifeArea != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(_selectedLifeArea!),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: _clearLifeAreaFilter,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          ),
                        ),
                      if (_selectedDateRange != null)
                        Chip(
                          label: Text(
                            '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: _clearDateRange,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredActivities.isEmpty
                    ? _buildEmptyState()
                    : RepaintBoundary(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredActivities.length,
                          itemBuilder: (context, index) {
                            final activity = _filteredActivities[index];
                            return RepaintBoundary(
                              child: _buildActivityCard(activity),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final hasActiveFilters = _selectedLifeArea != null || 
                            _selectedDateRange != null || 
                            _searchController.text.isNotEmpty;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilters ? Icons.filter_alt_off : Icons.insights_outlined,
              size: 72,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              hasActiveFilters 
                  ? 'No matching activities found'
                  : 'No activity insights yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasActiveFilters
                  ? 'Try adjusting your search terms or filters to find more activities'
                  : 'Start logging activities to see your insights here.\nYour journey begins with a single step!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedLifeArea = null;
                    _selectedDateRange = null;
                    _searchController.clear();
                  });
                  _performSearch();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear all filters'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final occurredAt = DateTime.parse(activity['occurred_at']);
    final templateName = activity['action_templates']?['name'] ?? '';
    
    // Parse notes data to get meaningful content
    final notesData = _parseNotesData(activity['notes']);
    
    // Use parsed title if available, otherwise template name
    final title = notesData['title'].toString().isNotEmpty 
        ? notesData['title'].toString()
        : templateName;
    
    // Use parsed plain text for notes display
    final notes = notesData['plainText'].toString();
    
    // Use parsed category if available, otherwise template category
    final notesCategory = notesData['category'].toString();
    final templateCategory = activity['action_templates']?['category'] ?? '';
    final categoryName = notesCategory.isNotEmpty ? notesCategory : templateCategory;
    
    // Find the color and display name for this category from life areas
    Color categoryColor = AppTheme.primaryColor;
    String displayName = categoryName.isNotEmpty ? categoryName : 'General';
    
    if (categoryName.isNotEmpty) {
      // Map common category names to life area names
      final categoryMapping = {
        'creativity': 'Creativity',
        'development': 'Development', 
        'learning': 'Learning',
        'art': 'Art',
        'fitness': 'Fitness',
        'health': 'Health',
        'work': 'Work',
        'social': 'Social',
        'family': 'Family',
        'general': 'General',
      };
      
      // Normalize category name
      final normalizedCategory = categoryMapping[categoryName.toLowerCase()] ?? categoryName;
      
      // Try exact match first
      for (final area in _lifeAreas) {
        if (area.name == normalizedCategory || area.category == normalizedCategory ||
            area.name == categoryName || area.category == categoryName) {
          categoryColor = _parseColor(area.color);
          displayName = area.name; // Use the life area name for display
          break;
        }
      }
      
      // If no exact match found, try case-insensitive match
      if (categoryColor == AppTheme.primaryColor) {
        for (final area in _lifeAreas) {
          if (area.name.toLowerCase() == normalizedCategory.toLowerCase() || 
              area.category.toLowerCase() == normalizedCategory.toLowerCase() ||
              area.name.toLowerCase() == categoryName.toLowerCase() || 
              area.category.toLowerCase() == categoryName.toLowerCase()) {
            categoryColor = _parseColor(area.color);
            displayName = area.name; // Use the life area name for display
            break;
          }
        }
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showActivityDetails(activity),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with life area and date
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(occurredAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Title
              Text(
                title.isNotEmpty ? title : 'Untitled Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: title.isEmpty ? colorScheme.onSurface.withValues(alpha: 0.5) : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Notes preview
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'No additional notes',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Stats
              Row(
                children: [
                  if (activity['duration_min'] != null) ...[
                    Icon(Icons.schedule, 
                      size: 16, 
                      color: colorScheme.onSurface.withValues(alpha: 0.5)
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity['duration_min']}m',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Icon(Icons.stars, 
                    size: 16, 
                    color: colorScheme.onSurface.withValues(alpha: 0.5)
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${activity['earned_xp'] ?? 0} XP',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, 
                    size: 12, 
                    color: colorScheme.onSurface.withValues(alpha: 0.3)
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}