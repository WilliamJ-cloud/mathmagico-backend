import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/activity_model.dart';

class ActivityCard extends StatefulWidget {
  final ActivityModel activity;
  final VoidCallback onTap;

  const ActivityCard({super.key, required this.activity, required this.onTap});

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  bool _pressed = false;

  List<Color> get _gradient {
    switch (widget.activity.type) {
      case ActivityType.sumaVisual:
        return [const Color(0xFF6C63FF), const Color(0xFF9C8FFF)];
      case ActivityType.conteo:
        return [const Color(0xFF2E7D32), const Color(0xFF66BB6A)];
      case ActivityType.comparar:
        return [const Color(0xFFC62828), const Color(0xFFEF5350)];
      case ActivityType.secuencias:
        return [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)];
      case ActivityType.reconocerNumeros:
        return [const Color(0xFF00838F), const Color(0xFF26C6DA)];
      case ActivityType.restaVisual:
        return [const Color(0xFFE65100), const Color(0xFFFF7043)];
      case ActivityType.subitizacion:
        return [const Color(0xFF00695C), const Color(0xFF26A69A)];
      case ActivityType.lineaNumerica:
        return [const Color(0xFF283593), const Color(0xFF5C6BC0)];
      case ActivityType.descomposicion:
        return [const Color(0xFFF57F17), const Color(0xFFFFCA28)];
      case ActivityType.trazarNumeros:
        return [const Color(0xFF1565C0), const Color(0xFF42A5F5)];
    }
  }

  String get _difficultyStars {
    switch (widget.activity.difficulty) {
      case Difficulty.easy:   return '⭐ Fácil';
      case Difficulty.medium: return '⭐⭐ Medio';
      case Difficulty.hard:   return '⭐⭐⭐ Difícil';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _gradient[0].withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // Decorative bubble top-right
                Positioned(
                  top: -22,
                  right: -22,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Decorative bubble bottom-left
                Positioned(
                  bottom: -18,
                  left: -14,
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.09),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Small dot top-left
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: emoji circle + points
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Emoji in white circle with shadow
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.activity.emoji,
                                style: const TextStyle(fontSize: 30),
                              ),
                            ),
                          ),
                          // Points badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('⭐',
                                    style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text(
                                  '+${widget.activity.pointsReward}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Title
                      Text(
                        widget.activity.title,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Bottom: difficulty + play button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _difficultyStars,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Play button
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: _gradient[0],
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
