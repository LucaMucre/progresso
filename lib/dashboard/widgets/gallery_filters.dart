import 'package:flutter/material.dart';
import '../../services/life_areas_service.dart';

class GalleryFilters extends StatelessWidget {
  final String? selectedAreaFilterName;
  final ValueChanged<String?> onSelected;

  const GalleryFilters({
    super.key,
    required this.selectedAreaFilterName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const areas = [
      'General',
      'Fitness',
      'Nutrition',
      'Learning',
      'Finance',
      'Art',
      'Relationships',
      'Spirituality',
      'Career',
    ];

    final String? display = selectedAreaFilterName;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: display == null || display.isEmpty,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...areas.map((name) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(name),
                  selected: display != null &&
                      LifeAreasService.canonicalAreaName(display) == LifeAreasService.canonicalAreaName(name),
                  onSelected: (_) => onSelected(name),
                ),
              )),
        ],
      ),
    );
  }
}

