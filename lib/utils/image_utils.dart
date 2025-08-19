import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';

class ImageUtils {
  /// Check if a URL is a base64 data URL
  static bool isBase64DataUrl(String url) {
    return url.startsWith('data:image/') && url.contains('base64,');
  }

  /// Build an image widget that supports both network URLs and base64 data URLs
  static Widget buildImageWidget({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    if (isBase64DataUrl(imageUrl)) {
      // Handle base64 data URL
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: memCacheWidth,
          cacheHeight: memCacheHeight,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _defaultErrorWidget();
          },
        );
      } catch (e) {
        return errorWidget ?? _defaultErrorWidget();
      }
    } else {
      // Handle network URL
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
        errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
      );
    }
  }

  static Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  static Widget _defaultErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}