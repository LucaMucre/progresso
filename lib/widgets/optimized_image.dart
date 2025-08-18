import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Optimized image widget with proper caching and loading states
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final bool enableThumbnails;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.enableThumbnails = true,
  });

  @override
  Widget build(BuildContext context) {
    // Generate thumbnail URL if enabled and dimensions provided
    // Temporarily disabled until Supabase transforms are properly configured
    final effectiveUrl = imageUrl; // enableThumbnails && (width != null || height != null)
        // ? _getThumbnailUrl(imageUrl, width, height)
        // : imageUrl;

    Widget image = CachedNetworkImage(
      imageUrl: effectiveUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth ?? (width?.toInt()),
      memCacheHeight: memCacheHeight ?? (height?.toInt()),
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  /// Generate Supabase thumbnail URL with transform parameters
  String _getThumbnailUrl(String originalUrl, double? width, double? height) {
    if (!originalUrl.contains('supabase')) {
      return originalUrl; // Not a Supabase URL, return as-is
    }

    try {
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the storage bucket and file path
      int storageIndex = pathSegments.indexOf('storage');
      if (storageIndex == -1 || storageIndex >= pathSegments.length - 3) {
        return originalUrl; // Invalid Supabase storage URL
      }

      final bucket = pathSegments[storageIndex + 2];
      final filePath = pathSegments.sublist(storageIndex + 3).join('/');

      // Build transform parameters
      final transforms = <String>[];
      if (width != null) transforms.add('width=${width.toInt()}');
      if (height != null) transforms.add('height=${height.toInt()}');
      transforms.add('quality=85'); // Good quality with compression
      transforms.add('format=webp'); // Use WebP for better compression

      final transformQuery = transforms.join(',');
      
      // Build new URL with transforms
      final newUri = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        pathSegments: [
          ...pathSegments.sublist(0, storageIndex),
          'storage',
          'v1',
          'render',
          'image',
          bucket,
          filePath,
        ],
        queryParameters: {'t': transformQuery},
      );

      return newUri.toString();
    } catch (e) {
      // If URL parsing fails, return original URL
      return originalUrl;
    }
  }

  Widget _defaultPlaceholder() {
    // For very small images, use a smaller progress indicator
    final isSmall = (width != null && width! < 50) || (height != null && height! < 50);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: isSmall ? 16 : 24,
          height: isSmall ? 16 : 24,
          child: CircularProgressIndicator(
            strokeWidth: isSmall ? 1.5 : 2,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget() {
    // For very small images, show just an icon
    final isSmall = (width != null && width! < 50) || (height != null && height! < 50);
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: isSmall
          ? Center(
              child: Icon(
                Icons.image,
                color: Colors.grey[400],
                size: (width != null && width! < 32) ? width! * 0.6 : 16,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image,
                  color: Colors.grey[400],
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Skeleton loader for images
class ImageSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ImageSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey,
        ),
      ),
    );
  }
}