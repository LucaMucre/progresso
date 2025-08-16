import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final EdgeInsets padding;
  const SkeletonList({Key? key, this.itemCount = 6, this.padding = const EdgeInsets.all(16)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets margin;
  const SkeletonCard({Key? key, this.height = 120, this.margin = const EdgeInsets.all(12)}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06)),
      ),
      child: const Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 140, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

