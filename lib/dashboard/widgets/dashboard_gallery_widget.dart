import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../../utils/app_theme.dart';
import '../../services/app_state.dart';
import '../../services/life_areas_service.dart';
import 'gallery_filters.dart';
import '../../widgets/skeleton.dart';
import '../../utils/logging_service.dart';
import '../../utils/image_utils.dart';

/// Extrahiertes Gallery-Widget aus dem Dashboard
/// Reduziert die Dashboard-Komplexität erheblich
class DashboardGalleryWidget extends ConsumerStatefulWidget {
  final String? selectedAreaFilterName;
  final Function(String?) onAreaSelected;
  final Function(String, int, int) onImageTap; // thumbUrl, width, quality
  final Future<List<Map<String, dynamic>>> Function({int limit, int offset}) fetchAllImages;

  const DashboardGalleryWidget({
    super.key,
    this.selectedAreaFilterName,
    required this.onAreaSelected,
    required this.onImageTap,
    required this.fetchAllImages,
  });

  @override
  ConsumerState<DashboardGalleryWidget> createState() => _DashboardGalleryWidgetState();
}

class _DashboardGalleryWidgetState extends ConsumerState<DashboardGalleryWidget> {
  int _refreshCounter = 0;

  String _thumbUrl(String publicUrl, {int width = 600, int quality = 80}) {
    try {
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 2) return publicUrl;
      
      final bucket = pathSegments[1];
      final objectPath = pathSegments.skip(2).join('/');
      
      return '${uri.scheme}://${uri.host}/render/image/authenticated/$bucket/$objectPath?width=$width&quality=$quality';
    } catch (e) {
      LoggingService.error('Error creating thumbnail URL', e);
      return publicUrl;
    }
  }

  String _extractActivityTitle(Map<String, dynamic> imageData) {
    try {
      final notes = imageData['notes'];
      if (notes != null) {
        final obj = jsonDecode(notes);
        if (obj is Map<String, dynamic> && obj['title'] != null) {
          return obj['title'].toString();
        }
      }
    } catch (e, stackTrace) {
      LoggingService.error('Error extracting activity title', e, stackTrace, 'DashboardGalleryWidget');
    }
    return 'Activity';
  }

  Map<String, dynamic> _extractActivityArea(Map<String, dynamic> imageData) {
    try {
      final notes = imageData['notes'];
      if (notes != null) {
        final obj = jsonDecode(notes);
        if (obj is Map<String, dynamic> && obj['area'] != null) {
          final areaName = obj['area'].toString();
          
          final defaultAreas = [
            {'name': 'Fitness', 'icon': Icons.fitness_center, 'color': '#FF5722'},
            {'name': 'Nutrition', 'icon': Icons.restaurant, 'color': '#4CAF50'},
            {'name': 'Learning', 'icon': Icons.school, 'color': '#2196F3'},
            {'name': 'Finance', 'icon': Icons.account_balance, 'color': '#FFC107'},
            {'name': 'Art', 'icon': Icons.palette, 'color': '#9C27B0'},
            {'name': 'Relationships', 'icon': Icons.people, 'color': '#E91E63'},
            {'name': 'Spirituality', 'icon': Icons.self_improvement, 'color': '#607D8B'},
            {'name': 'Career', 'icon': Icons.work, 'color': '#795548'},
          ];
          
          final area = defaultAreas.firstWhere(
            (a) => a['name'] == areaName || 
                   LifeAreasService.canonicalAreaName(a['name'] as String?) == LifeAreasService.canonicalAreaName(areaName),
            orElse: () => {'name': 'General', 'icon': Icons.circle, 'color': '#666666'},
          );
          
          return {
            'name': area['name'],
            'icon': area['icon'],
            'color': area['color'],
          };
        }
      }
    } catch (e, stackTrace) {
      LoggingService.error('Error extracting activity area', e, stackTrace, 'DashboardGalleryWidget');
    }

    return {
      'name': 'General',
      'icon': Icons.circle,
      'color': '#666666',
    };
  }

  Widget _buildImageGrid(List<Map<String, dynamic>> images) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final imageUrl = image['image_url'] as String;
        final title = _extractActivityTitle(image);
        final area = _extractActivityArea(image);
        final date = DateTime.parse(image['occurred_at']);

        return GestureDetector(
          onTap: () => _showImageFullscreen(context, image, images, index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageUtils.buildImageWidget(
                    imageUrl: ImageUtils.isBase64DataUrl(imageUrl) ? imageUrl : _thumbUrl(imageUrl),
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  // Overlay with gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Area tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(int.parse(area['color'].substring(1), radix: 16) + 0xFF000000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  area['icon'],
                                  color: Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  area['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Date
                          Text(
                            DateFormat('MMM d').format(date),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageFullscreen(BuildContext context, Map<String, dynamic> imageData, List<Map<String, dynamic>> allImages, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                final data = allImages[index];
                final imageUrl = data['image_url'] as String;
                final date = DateTime.parse(data['occurred_at']);
                final title = _extractActivityTitle(data);
                final area = _extractActivityArea(data);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      child: ImageUtils.buildImageWidget(
                        imageUrl: ImageUtils.isBase64DataUrl(imageUrl) ? imageUrl : _thumbUrl(imageUrl, width: 2000, quality: 90),
                        fit: BoxFit.contain,
                        placeholder: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    // Bottom info overlay
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(area['color'].substring(1), radix: 16) + 0xFF000000),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        area['icon'],
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        area['name'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d, y • h:mm a').format(date),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_library,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Photo Gallery',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              'All your memories',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Gallery filter chips by life area
        GalleryFilters(
          selectedAreaFilterName: widget.selectedAreaFilterName,
          onSelected: (name) => {
            widget.onAreaSelected(name),
            setState(() => _refreshCounter++),
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320, // Reduced height for gallery (proportional to main container reduction)
          child: Consumer(
            builder: (context, ref, _) {
              final logsAsync = ref.watch(logsNotifierProvider);
              return logsAsync.when(
                loading: () => const Center(child: SkeletonCard(height: 180)),
                error: (e, st) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(height: AppTheme.spacing16),
                      Text(
                        'Error loading photos',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                ),
                data: (_) {
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    key: ValueKey(_refreshCounter),
                    future: widget.fetchAllImages(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: SkeletonCard(height: 180));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              SizedBox(height: AppTheme.spacing16),
                              Text(
                                'Error loading photos',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ),
                        );
                      }
                      List<Map<String, dynamic>> images = List<Map<String, dynamic>>.from(snapshot.data ?? const []);
                      
                      // Apply client-side filter by life area if selected
                      if (widget.selectedAreaFilterName != null && widget.selectedAreaFilterName!.trim().isNotEmpty) {
                        final selectedCanonical = LifeAreasService.canonicalAreaName(widget.selectedAreaFilterName);
                        images = images.where((img) {
                          final area = _extractActivityArea(img);
                          final name = area['name'] as String?;
                          return LifeAreasService.canonicalAreaName(name) == selectedCanonical;
                        }).toList();
                      }
                      
                      if (images.isEmpty) {
                        return const Center(child: Text('No photos yet'));
                      }
                      
                      return _buildImageGrid(images);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}