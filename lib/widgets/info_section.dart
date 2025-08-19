import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Wiederverwendbares Info-Section Widget
/// Abstrahiert gemeinsames UI-Pattern für Titel + Untertitel Sektionen
class InfoSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment alignment;

  const InfoSection({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.trailing,
    this.padding,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: alignment,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: titleStyle ?? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: subtitleStyle ?? theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Spezialisierte Version für Statistiken
class StatisticsInfoSection extends InfoSection {
  const StatisticsInfoSection({
    super.key,
    required super.title,
    super.subtitle = 'All activities across all life areas',
    super.icon = Icons.analytics_outlined,
    super.padding = const EdgeInsets.only(bottom: AppTheme.spacing16),
  });
}

/// Spezialisierte Version für Aktionen/Features
class FeatureInfoSection extends InfoSection {
  const FeatureInfoSection({
    super.key,
    required super.title,
    super.subtitle = 'Quick access to all activities',
    super.icon = Icons.flash_on_outlined,
    super.padding = const EdgeInsets.only(bottom: AppTheme.spacing16),
  });
}

/// Container Widget für Sektionen mit Hintergrund
class SectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final bool hasShadow;
  
  const SectionContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTheme.spacing20),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.backgroundColor,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: child,
    );
  }
}