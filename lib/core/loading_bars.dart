import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingBars extends StatefulWidget {
  final Color color;
  final double height;
  final double barWidth;
  final int barCount;

  const LoadingBars({
    super.key,
    this.color = Colors.white,
    this.height = 20,
    this.barWidth = 3.5,
    this.barCount = 6,
  });

  @override
  State<LoadingBars> createState() => _LoadingBarsState();
}

class _LoadingBarsState extends State<LoadingBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              // Each bar has a different phase offset for wave effect
              final phase = index / widget.barCount;
              final wave = math.sin((_controller.value + phase) * math.pi * 2);
              // Map sine wave (-1 to 1) to height fraction (0.25 to 1.0)
              final heightFraction = 0.25 + (wave + 1) / 2 * 0.75;

              return Container(
                width: widget.barWidth,
                height: widget.height * heightFraction,
                margin: EdgeInsets.symmetric(horizontal: widget.barWidth * 0.4),
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: 0.6 + (wave + 1) / 2 * 0.4,
                  ),
                  borderRadius: BorderRadius.circular(widget.barWidth),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  final Color color;
  final double size;

  const LoadingDots({
    super.key,
    this.color = Colors.white,
    this.size = 8,
  });

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final t = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = math.sin(t * math.pi);

            return Container(
              width: widget.size,
              height: widget.size,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.4 + bounce * 0.6),
                shape: BoxShape.circle,
              ),
              transform: Matrix4.translationValues(0, -bounce * 4, 0),
            );
          }),
        );
      },
    );
  }
}
