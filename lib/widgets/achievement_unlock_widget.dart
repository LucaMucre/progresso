import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/achievement_service.dart';
import '../utils/app_theme.dart';
import '../utils/animation_utils.dart';

class AchievementUnlockWidget extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onDismissed;
  
  const AchievementUnlockWidget({
    super.key,
    required this.achievement,
    this.onDismissed,
  });
  
  @override
  State<AchievementUnlockWidget> createState() => _AchievementUnlockWidgetState();
}

class _AchievementUnlockWidgetState extends State<AchievementUnlockWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _particleController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _particleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Slide in animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    // Scale animation for icon
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));
    
    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // Particle animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleController);
    
    // Start animations with delays
    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _glowController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _particleController.forward();
    });
    
    // Auto dismiss after 4 seconds – aber ohne unnötigen Bildschirm-Reload
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }
  
  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    super.dispose();
  }
  
  void _dismiss() {
    if (!_slideController.isAnimating) {
      _slideController.reverse().whenComplete(() {
        widget.onDismissed?.call();
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            
            // Achievement card
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: widget.achievement.color.withValues(alpha: 0.4 * _glowAnimation.value),
                              blurRadius: 25 + (40 * _glowAnimation.value),
                              spreadRadius: 8 + (15 * _glowAnimation.value),
                            ),
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2 * _glowAnimation.value),
                              blurRadius: 40 + (60 * _glowAnimation.value),
                              spreadRadius: 15 + (25 * _glowAnimation.value),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: widget.achievement.color.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // "Achievement Unlocked" header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: widget.achievement.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: widget.achievement.color.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  '🏆 Achievement Freigeschaltet!',
                                  style: TextStyle(
                                    color: widget.achievement.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Animated icon with particles
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Particle effects
                                  AnimatedBuilder(
                                    animation: _particleAnimation,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(120, 120),
                                        painter: ParticlePainter(
                                          animation: _particleAnimation,
                                          color: widget.achievement.color,
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  // Main icon
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: widget.achievement.color,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: widget.achievement.color.withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        widget.achievement.icon,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Title
                              Text(
                                widget.achievement.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: widget.achievement.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Description
                              Text(
                                widget.achievement.description,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Close button
                  ElevatedButton(
                                onPressed: _dismiss,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.achievement.color,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                 child: const Text('Great!'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  
  ParticlePainter({required this.animation, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;
    
    // Draw multiple particles in a circle
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30.0) * (3.14159 / 180); // Convert to radians
      final distance = progress * 40;
      final particleSize = (1 - progress) * 4 + 2;
      
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);
      
      paint.color = color.withValues(alpha: (1 - progress) * 0.8);
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
    
    // Draw sparkles
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0 + progress * 360) * (3.14159 / 180);
      final distance = 30 + progress * 15;
      final sparkleSize = math.sin(progress * 3.14159) * 3;
      
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);
      
      paint.color = Colors.yellow.withValues(alpha: math.sin(progress * 3.14159) * 0.8);
      canvas.drawCircle(Offset(x, y), sparkleSize, paint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}