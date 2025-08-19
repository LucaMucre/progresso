import 'package:flutter/material.dart';
import 'dart:ui';
import '../../utils/app_theme.dart';
import '../../utils/modern_animations.dart';

/// Extrahierte Stats-Sektion aus dem Dashboard
/// Reduziert die Dashboard-Komplexität erheblich
class DashboardStatsWidget extends StatelessWidget {
  final int totalActivities;
  final int totalXP;
  final int currentStreak;
  final int longestStreak;
  final bool isLoading;

  const DashboardStatsWidget({
    super.key,
    required this.totalActivities,
    required this.totalXP,
    required this.currentStreak,
    required this.longestStreak,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _StatsLoadingWidget();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.glassContainer(
              color: AppTheme.primaryColor,
              opacity: 0.08,
              borderRadius: 20.0,
              borderOpacity: 0.15,
            ),
            child: ModernAnimations.fadeInScale(
              duration: const Duration(milliseconds: 600),
              child: Column(
                children: [
                  Text(
                    'Your Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggeredAnimatedList(
                    direction: Axis.vertical,
                    staggerDelay: const Duration(milliseconds: 150),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Activities',
                              value: totalActivities.toString(),
                              icon: Icons.fitness_center,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'XP',
                              value: totalXP.toString(),
                              icon: Icons.star,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Streak',
                              value: currentStreak.toString(),
                              icon: Icons.local_fire_department,
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Record',
                              value: longestStreak.toString(),
                              icon: Icons.emoji_events,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassContainer(
        color: color,
        opacity: 0.06,
        borderRadius: 16.0,
        borderOpacity: 0.12,
      ).copyWith(
        boxShadow: AppTheme.modernShadow(elevation: 2.0, color: color),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatsLoadingWidget extends StatelessWidget {
  const _StatsLoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            height: 24,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < 2; i++) ...[
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (i < 1) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 2; i++) ...[
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (i < 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}