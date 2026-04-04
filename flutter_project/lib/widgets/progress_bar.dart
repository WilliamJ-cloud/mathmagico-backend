import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double value;       // 0.0 - 1.0
  final Color? color;
  final double height;
  final String? label;
  final bool showPercentage;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 10,
    this.label,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    final clampedValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (showPercentage)
                  Text(
                    '${(clampedValue * 100).toInt()}%',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              // Fondo
              Container(
                height: height,
                color: barColor.withOpacity(0.12),
              ),
              // Relleno animado
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                widthFactor: clampedValue,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indicador circular de progreso con porcentaje
class CircularProgressWidget extends StatelessWidget {
  final double value;
  final Color? color;
  final double size;
  final String? label;

  const CircularProgressWidget({
    super.key,
    required this.value,
    this.color,
    this.size = 80,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    final clampedValue = value.clamp(0.0, 1.0);
    final pct = (clampedValue * 100).toInt();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clampedValue,
              strokeWidth: size * 0.08,
              backgroundColor: barColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$pct%',
                style: GoogleFonts.nunito(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  color: barColor,
                ),
              ),
              if (label != null)
                Text(
                  label!,
                  style: GoogleFonts.nunito(
                    fontSize: size * 0.13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut);
  }
}

/// Barra de XP de nivel (con estrella y nivel actual)
class LevelProgressBar extends StatelessWidget {
  final int currentPoints;
  final int currentLevel;
  final double levelProgress;

  const LevelProgressBar({
    super.key,
    required this.currentPoints,
    required this.currentLevel,
    required this.levelProgress,
  });

  static const List<int> _levelThresholds = [0, 100, 300, 600, 1000];

  @override
  Widget build(BuildContext context) {
    final nextLevel = (currentLevel + 1).clamp(1, 5);
    final nextPts = currentLevel < 5 ? _levelThresholds[currentLevel] : 9999;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('⭐', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(
                    'Nivel $currentLevel',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                currentLevel < 5
                    ? '$currentPoints / $nextPts pts'
                    : '¡Nivel máximo! 🏆',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(
            value: levelProgress,
            color: AppColors.accent,
            height: 12,
          ),
          if (currentLevel < 5) ...[
            const SizedBox(height: 4),
            Text(
              '${nextPts - currentPoints} puntos para nivel $nextLevel',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}