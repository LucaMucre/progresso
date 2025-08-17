import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/animation_utils.dart';

/// Modern card widget with enhanced visuals and animations
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final bool gradient;
  final List<Color>? gradientColors;
  final bool glassMorphism;
  final VoidCallback? onTap;
  final bool animateOnTap;
  final bool slideInAnimation;
  final Duration? animationDelay;
  
  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient = false,
    this.gradientColors,
    this.glassMorphism = false,
    this.onTap,
    this.animateOnTap = true,
    this.slideInAnimation = false,
    this.animationDelay,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }
  
  void _onTapDown(TapDownDetails details) {
    if (widget.animateOnTap && widget.onTap != null) {
      _scaleController.forward();
    }
  }
  
  void _onTapUp(TapUpDetails details) {
    if (widget.animateOnTap && widget.onTap != null) {
      _scaleController.reverse();
    }
  }
  
  void _onTapCancel() {
    if (widget.animateOnTap && widget.onTap != null) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: widget.margin ?? const EdgeInsets.all(8),
            decoration: _buildDecoration(context),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: widget.padding ?? const EdgeInsets.all(16),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
    
    if (widget.slideInAnimation) {
      card = AnimationUtils.slideAndFade(
        child: card,
        duration: widget.animationDelay ?? AnimationUtils.normal,
      );
    }
    
    return card;
  }
  
  BoxDecoration _buildDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (widget.glassMorphism) {
      return AppTheme.glassContainer(context: context);
    }
    
    if (widget.gradient && widget.gradientColors != null) {
      return AppTheme.gradientContainer(
        colors: widget.gradientColors!,
        boxShadow: AppTheme.modernCardShadow(context),
      );
    }
    
    return BoxDecoration(
      color: widget.backgroundColor ?? colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppTheme.modernCardShadow(context),
    );
  }
}

/// Quick builder for activity cards
class ActivityCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final Color? accentColor;
  
  const ActivityCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.actions,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ModernCard(
      onTap: onTap,
      slideInAnimation: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Stats card with gradient background
class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  
  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.gradientColors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = gradientColors ?? AppTheme.primaryGradient;
    
    return ModernCard(
      gradient: true,
      gradientColors: colors,
      onTap: onTap,
      slideInAnimation: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}