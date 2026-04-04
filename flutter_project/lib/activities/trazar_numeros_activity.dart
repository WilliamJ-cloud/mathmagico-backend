import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

// ---------------------------------------------------------------------------
// Waypoints for digits 1–9 (x, y as fractions of the 200×200 canvas)
// ---------------------------------------------------------------------------
const Map<int, List<Offset>> _kWaypoints = {
  1: [Offset(0.5, 0.2), Offset(0.5, 0.5), Offset(0.5, 0.8)],
  2: [
    Offset(0.3, 0.2),
    Offset(0.7, 0.2),
    Offset(0.7, 0.5),
    Offset(0.3, 0.8),
    Offset(0.7, 0.8),
  ],
  3: [
    Offset(0.3, 0.2),
    Offset(0.7, 0.3),
    Offset(0.5, 0.5),
    Offset(0.7, 0.7),
    Offset(0.3, 0.8),
  ],
  4: [
    Offset(0.38, 0.10), // 1 – arriba-izquierda: inicio del brazo diagonal
    Offset(0.20, 0.58), // 2 – abajo-izquierda: fin del brazo (diagonal hacia la izq.)
    Offset(0.65, 0.58), // 3 – abajo-derecha: barra horizontal hasta la unión
    Offset(0.65, 0.10), // 4 – arriba-derecha: sube al tope del trazo vertical
    Offset(0.65, 0.88), // 5 – abajo-derecha: baja todo el trazo vertical
  ],
  5: [
    Offset(0.7, 0.2),
    Offset(0.3, 0.2),
    Offset(0.3, 0.5),
    Offset(0.7, 0.5),
    Offset(0.7, 0.8),
    Offset(0.3, 0.8),
  ],
  6: [
    Offset(0.7, 0.2),
    Offset(0.3, 0.4),
    Offset(0.3, 0.7),
    Offset(0.5, 0.85),
    Offset(0.7, 0.7),
    Offset(0.5, 0.5),
    Offset(0.3, 0.6),
  ],
  7: [Offset(0.3, 0.2), Offset(0.7, 0.2), Offset(0.4, 0.8)],
  8: [
    Offset(0.5, 0.2),
    Offset(0.7, 0.35),
    Offset(0.5, 0.5),
    Offset(0.3, 0.65),
    Offset(0.5, 0.8),
    Offset(0.7, 0.65),
    Offset(0.5, 0.5),
  ],
  9: [
    Offset(0.5, 0.2),
    Offset(0.7, 0.35),
    Offset(0.5, 0.5),
    Offset(0.3, 0.35),
    Offset(0.5, 0.2),
    Offset(0.5, 0.8),
  ],
};

// ---------------------------------------------------------------------------
// CustomPainter – draws lines between tapped waypoints
// ---------------------------------------------------------------------------
class _WaypointPainter extends CustomPainter {
  final List<Offset> waypoints;
  final int nextToTap;
  final double canvasSize;

  const _WaypointPainter({
    required this.waypoints,
    required this.nextToTap,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Guía punteada (camino completo) ────────────────────
    final guidePaint = Paint()
      ..color = Colors.grey.withOpacity(0.30)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < waypoints.length; i++) {
      final p1 = Offset(waypoints[i - 1].dx * canvasSize, waypoints[i - 1].dy * canvasSize);
      final p2 = Offset(waypoints[i].dx * canvasSize, waypoints[i].dy * canvasSize);
      // Línea punteada
      const gap = 8.0;
      final dx = p2.dx - p1.dx;
      final dy = p2.dy - p1.dy;
      final dist = (Offset(dx, dy)).distance;
      final steps = (dist / gap).floor();
      for (int s = 0; s < steps; s += 2) {
        final t0 = s / steps;
        final t1 = (s + 1) / steps;
        canvas.drawLine(
          Offset(p1.dx + dx * t0, p1.dy + dy * t0),
          Offset(p1.dx + dx * t1, p1.dy + dy * t1),
          guidePaint,
        );
      }
    }

    // ── Trazo completado (verde) ────────────────────────────
    if (nextToTap < 2) return;

    final paint = Paint()
      ..color = AppColors.success.withOpacity(0.8)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < nextToTap; i++) {
      final p1 = Offset(waypoints[i - 1].dx * canvasSize, waypoints[i - 1].dy * canvasSize);
      final p2 = Offset(waypoints[i].dx * canvasSize, waypoints[i].dy * canvasSize);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(_WaypointPainter old) => old.nextToTap != nextToTap;
}

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------
class TrazarNumerosActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const TrazarNumerosActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<TrazarNumerosActivity> createState() => _TrazarNumerosActivityState();
}

class _TrazarNumerosActivityState extends State<TrazarNumerosActivity>
    with SingleTickerProviderStateMixin {
  int _nextToTap = 0;
  bool _completed = false;
  bool _shaking = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  static const double _canvasSize = 200.0;
  static const double _dotRadius = 18.0;
  static const double _tapRadius = 32.0;

  int get _numberToTrace => (widget.question.operands.isNotEmpty
          ? widget.question.operands[0] as int
          : widget.question.correctAnswer)
      .clamp(1, 9);

  List<Offset> get _waypoints =>
      _kWaypoints[_numberToTrace] ?? _kWaypoints[1]!;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.linear,
    ));
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _shaking = false);
      }
    });

    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 400));
    context.read<AudioService>().speak(
          'Toca los puntos en orden para trazar el número $_numberToTrace.',
        );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _tapWaypoint(int index) {
    if (_completed) return;

    if (index == _nextToTap) {
      // Correct tap
      HapticFeedback.lightImpact();
      context.read<AudioService>().speakNumber(index + 1);
      setState(() => _nextToTap++);

      if (_nextToTap == _waypoints.length) {
        // All waypoints tapped — done
        setState(() => _completed = true);
        HapticFeedback.mediumImpact();
        context.read<AudioService>().speakCorrect();
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onAnswer(widget.question.correctAnswer);
        });
      }
    } else {
      // Wrong order
      HapticFeedback.heavyImpact();
      setState(() => _shaking = true);
      _shakeController.forward(from: 0);
      context.read<AudioService>().speak('Toca el punto número ${_nextToTap + 1}.');
    }
  }

  void _reset() {
    setState(() {
      _nextToTap = 0;
      _completed = false;
    });
    context.read<AudioService>().speak('Vamos a intentarlo de nuevo.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInstructionBanner(),
        const SizedBox(height: 16),
        _buildTracingCard(),
        const SizedBox(height: 16),
        _buildProgressIndicator(),
        const SizedBox(height: 12),
        if (!_completed)
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'Volver a intentar',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildInstructionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('✏️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Toca los puntos en orden: 1, 2, 3…',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTracingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _completed
              ? AppColors.success.withOpacity(0.4)
              : AppColors.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Number being traced
          Text(
            'Traza el número',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shaking ? _shakeAnim.value : 0, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: _canvasSize,
              height: _canvasSize,
              child: Stack(
                children: [
                  // Large guide number
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        '$_numberToTrace',
                        style: GoogleFonts.nunito(
                          fontSize: 180,
                          fontWeight: FontWeight.w900,
                          color: _completed
                              ? AppColors.success.withOpacity(0.15)
                              : AppColors.textHint.withOpacity(0.12),
                        ),
                      ),
                    ),
                  ),

                  // Lines between tapped waypoints
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WaypointPainter(
                        waypoints: _waypoints,
                        nextToTap: _nextToTap,
                        canvasSize: _canvasSize,
                      ),
                    ),
                  ),

                  // Waypoint dots
                  ..._waypoints.asMap().entries.map((entry) {
                    final i = entry.key;
                    final pos = entry.value;
                    final isTapped = i < _nextToTap;
                    final isNext = i == _nextToTap && !_completed;

                    Color bgColor;
                    Color borderColor;
                    Color textColor;

                    if (isTapped) {
                      bgColor = AppColors.success;
                      borderColor = AppColors.success;
                      textColor = Colors.white;
                    } else if (isNext) {
                      bgColor = AppColors.primary;
                      borderColor = AppColors.primary;
                      textColor = Colors.white;
                    } else {
                      bgColor = Colors.grey.shade100;
                      borderColor = Colors.grey.shade300;
                      textColor = AppColors.textHint;
                    }

                    return Positioned(
                      left: pos.dx * _canvasSize - _dotRadius,
                      top: pos.dy * _canvasSize - _dotRadius,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tapWaypoint(i),
                        child: SizedBox(
                          width: _tapRadius * 2,
                          height: _tapRadius * 2,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _dotRadius * 2,
                              height: _dotRadius * 2,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: borderColor,
                                  width: 2.5,
                                ),
                                boxShadow: isNext
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            )
                                .animate(
                                  target: isNext ? 1 : 0,
                                  onPlay: (c) =>
                                      isNext ? c.repeat(reverse: true) : null,
                                )
                                .scale(
                                  begin: const Offset(1.0, 1.0),
                                  end: const Offset(1.2, 1.2),
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOut,
                                ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Completion overlay
                  if (_completed)
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🎉',
                              style: TextStyle(fontSize: 48),
                            ).animate().scale(
                                  begin: const Offset(0.3, 0.3),
                                  curve: Curves.elasticOut,
                                  duration: const Duration(milliseconds: 600),
                                ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildProgressIndicator() {
    final total = _waypoints.length;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Puntos tocados: ',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '$_nextToTap / $total',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _completed ? AppColors.success : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: total > 0 ? _nextToTap / total : 0,
            minHeight: 10,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              _completed ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
