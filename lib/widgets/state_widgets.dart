import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Abstrahiert gemeinsame Loading/Error/Empty States
/// Reduziert Code-Duplikation in der gesamten App
class StateWidget extends StatelessWidget {
  final StateType type;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final Widget? child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const StateWidget({
    super.key,
    required this.type,
    this.message,
    this.icon,
    this.onRetry,
    this.child,
    this.height,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
  });

  const StateWidget.loading({
    super.key,
    this.message = 'Loading...',
    this.height,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
  }) : type = StateType.loading,
       icon = null,
       onRetry = null,
       child = null;

  const StateWidget.error({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
    this.icon = Icons.error_outline,
    this.height,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
  }) : type = StateType.error,
       child = null;

  const StateWidget.empty({
    super.key,
    this.message = 'No data available',
    this.icon = Icons.inbox_outlined,
    this.height,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
  }) : type = StateType.empty,
       onRetry = null,
       child = null;

  const StateWidget.custom({
    super.key,
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
  }) : type = StateType.custom,
       message = null,
       icon = null,
       onRetry = null;

  @override
  Widget build(BuildContext context) {
    Widget content;
    
    switch (type) {
      case StateType.loading:
        content = _buildLoading(context);
        break;
      case StateType.error:
        content = _buildError(context);
        break;
      case StateType.empty:
        content = _buildEmpty(context);
        break;
      case StateType.custom:
        content = child!;
        break;
    }

    return Container(
      height: height,
      padding: padding,
      child: Center(child: content),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: AppTheme.spacing16),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
        if (message != null) ...[
          Text(
            message!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
        if (onRetry != null)
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
        if (message != null)
          Text(
            message!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

enum StateType { loading, error, empty, custom }

/// Async State Builder Widget - Vereinfacht AsyncValue handling
class AsyncStateBuilder<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;
  final String? loadingMessage;
  final String? errorMessage;

  const AsyncStateBuilder({
    super.key,
    required this.asyncValue,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.loadingMessage,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => loadingBuilder?.call(context) ?? StateWidget.loading(
        message: loadingMessage,
      ),
      error: (error, stackTrace) => errorBuilder?.call(context, error, stackTrace) ?? StateWidget.error(
        message: errorMessage ?? 'Error: $error',
        onRetry: () {
          // Retry callback would be handled externally
        },
      ),
      data: (data) => dataBuilder(context, data),
    );
  }
}

/// Spezialisierte Widgets für häufige Use Cases
class CalendarStateWidget extends StateWidget {
  const CalendarStateWidget.loading({super.key}) 
      : super.loading(message: 'Loading calendar...');
  
  const CalendarStateWidget.error({super.key, VoidCallback? onRetry})
      : super.error(message: 'Error loading calendar', onRetry: onRetry);
}

class PhotosStateWidget extends StateWidget {
  const PhotosStateWidget.loading({super.key})
      : super.loading(message: 'Loading photos...');
  
  const PhotosStateWidget.error({super.key, VoidCallback? onRetry})
      : super.error(message: 'Error loading photos', onRetry: onRetry);
  
  const PhotosStateWidget.empty({super.key})
      : super.empty(message: 'No photos yet', icon: Icons.photo_library_outlined);
}

class StatisticsStateWidget extends StateWidget {
  const StatisticsStateWidget.loading({super.key})
      : super.loading(message: 'Loading statistics...');
  
  const StatisticsStateWidget.error({super.key, VoidCallback? onRetry})
      : super.error(message: 'Error loading statistics', onRetry: onRetry);
}