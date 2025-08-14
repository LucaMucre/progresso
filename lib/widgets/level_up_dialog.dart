import 'package:flutter/material.dart';

class LevelUpDialog extends StatefulWidget {
  final int level;
  const LevelUpDialog({super.key, required this.level});

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scaleController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _glowController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    _scaleAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _scaleController, curve: Curves.bounceOut));
    _glowAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    // Start animations only while mounted to avoid forward() after dispose
    if (mounted) _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () { if (mounted) _scaleController.forward(); });
    Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _glowController.forward(); });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    return Material(
      color: Colors.black.withAlpha(77),
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant, width: 2),
              boxShadow: [
                BoxShadow(
                  color: primary.withAlpha((0.3 * 255 * _glowAnimation.value).toInt()),
                  blurRadius: 20 + (30 * _glowAnimation.value),
                  spreadRadius: 5 + (10 * _glowAnimation.value),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: primary.withAlpha(77), blurRadius: 15, spreadRadius: 5),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Level Up!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: primary)),
                const SizedBox(height: 8),
                Text('You reached Level ${widget.level}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Awesome!'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

