import 'package:flutter/material.dart';

/// Modern animation utilities for enhanced user experience
class ModernAnimations {
  /// Gentle bounce animation for interactive elements
  static Widget bounceOnTap({
    required Widget child,
    VoidCallback? onTap,
    double scale = 0.95,
    Duration duration = const Duration(milliseconds: 100),
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(begin: 1.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) => {},
        onTapCancel: () => {},
        onTap: onTap,
        child: child,
      ),
    );
  }

  /// Staggered animation for lists
  static Widget staggeredSlideIn({
    required Widget child,
    required int index,
    Duration delay = const Duration(milliseconds: 100),
    Duration duration = const Duration(milliseconds: 600),
    Offset offset = const Offset(0, 50),
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: offset * (1 - value),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Fade in animation with scale
  static Widget fadeInScale({
    required Widget child,
    Duration duration = const Duration(milliseconds: 500),
    double initialScale = 0.8,
    Curve curve = Curves.easeOutBack,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: curve,
      builder: (context, value, child) {
        final scale = initialScale + (1.0 - initialScale) * value;
        final opacity = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Shimmer loading effect
  static Widget shimmer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
    Color? highlightColor,
    Color? baseColor,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween<double>(begin: -1.0, end: 1.0),
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor ?? Colors.grey[300]!,
                highlightColor ?? Colors.grey[100]!,
                baseColor ?? Colors.grey[300]!,
              ],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }

  /// Slide transition between pages
  static PageRouteBuilder<T> slideRoute<T>({
    required Widget page,
    SlideDirection direction = SlideDirection.right,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    Offset getOffset() {
      switch (direction) {
        case SlideDirection.right:
          return const Offset(1.0, 0.0);
        case SlideDirection.left:
          return const Offset(-1.0, 0.0);
        case SlideDirection.up:
          return const Offset(0.0, 1.0);
        case SlideDirection.down:
          return const Offset(0.0, -1.0);
      }
    }

    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, _) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: getOffset(),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: child,
        );
      },
    );
  }

  /// Smooth container transition
  static Widget smoothContainer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
    BoxDecoration? decoration,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? width,
    double? height,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      decoration: decoration,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      child: child,
    );
  }
}

enum SlideDirection { right, left, up, down }

/// Enhanced AnimatedList with staggered animations
class StaggeredAnimatedList extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final Axis direction;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  const StaggeredAnimatedList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.animationDuration = const Duration(milliseconds: 600),
    this.direction = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: direction,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        
        return ModernAnimations.staggeredSlideIn(
          index: index,
          delay: staggerDelay * index,
          duration: animationDuration,
          child: child,
        );
      }).toList(),
    );
  }
}