import 'package:flutter/material.dart';

/// Modern animation utilities for smooth user experience
class AnimationUtils {
  // Animation durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  // Animation curves
  static const Curve easeInOutQuart = Cubic(0.77, 0, 0.175, 1);
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1);
  static const Curve bounceOut = Cubic(0.68, -0.55, 0.265, 1.55);
  
  /// Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = Curves.easeOut,
    double begin = 0.0,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Slide in from bottom animation
  static Widget slideInFromBottom({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeInOutQuart,
    double begin = 50.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 0.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Scale in animation
  static Widget scaleIn({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeOutBack,
    double begin = 0.8,
    double end = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: end),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Shimmer loading effect
  static Widget shimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -1.0, end: 1.0),
      duration: duration,
      curve: Curves.linear,
      builder: (context, value, child) {
        final theme = Theme.of(context);
        final base = baseColor ?? theme.colorScheme.surfaceContainerHighest;
        final highlight = highlightColor ?? theme.colorScheme.surfaceContainerHigh;
        
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + value, 0.0),
              end: Alignment(1.0 + value, 0.0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }
  
  /// Bouncy entrance animation
  static Widget bounceIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: bounceOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  /// Slide and fade animation
  static Widget slideAndFade({
    required Widget child,
    Duration duration = normal,
    Curve curve = easeInOutQuart,
    Offset beginOffset = const Offset(0, 30),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            beginOffset.dx * (1 - value),
            beginOffset.dy * (1 - value),
          ),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  /// Staggered list animation
  static Widget staggeredList({
    required List<Widget> children,
    Duration staggerDelay = const Duration(milliseconds: 100),
    Duration animationDuration = normal,
  }) {
    return Column(
      children: List.generate(children.length, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: animationDuration,
          curve: easeInOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: children[index],
        );
      }),
    );
  }
}

/// Custom page transition animations
class CustomPageTransitions {
  static PageRouteBuilder slideFromRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AnimationUtils.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final offsetAnimation = animation.drive(
          tween.chain(CurveTween(curve: AnimationUtils.easeInOutQuart)),
        );
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
  
  static PageRouteBuilder fadeScale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AnimationUtils.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: AnimationUtils.easeOutBack,
              ),
            ),
            child: child,
          ),
        );
      },
    );
  }
}