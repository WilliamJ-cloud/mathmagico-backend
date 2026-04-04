import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class SubitizacionActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const SubitizacionActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<SubitizacionActivity> createState() => _SubitizacionActivityState();
}

class _SubitizacionActivityState extends State<SubitizacionActivity> {
  int? _selectedAnswer;
  bool _answered = false;
  bool _dotsVisible = true;
  Timer? _hideTimer;

  // Pre-computed pseudo-random positions for dots (normalized 0.0–1.0 in a 220x220 box)
  // Arranged so dots never overlap; indexed by count 1-9.
  static const List<List<Offset>> _dotPositions = [
    // 1 dot
    [Offset(0.5, 0.5)],
    // 2 dots
    [Offset(0.25, 0.5), Offset(0.75, 0.5)],
    // 3 dots
    [Offset(0.25, 0.3), Offset(0.75, 0.3), Offset(0.5, 0.75)],
    // 4 dots
    [Offset(0.2, 0.25), Offset(0.75, 0.25), Offset(0.2, 0.75), Offset(0.75, 0.75)],
    // 5 dots
    [Offset(0.2, 0.2), Offset(0.75, 0.2), Offset(0.5, 0.5), Offset(0.2, 0.8), Offset(0.75, 0.8)],
    // 6 dots
    [Offset(0.2, 0.2), Offset(0.75, 0.2), Offset(0.2, 0.5), Offset(0.75, 0.5), Offset(0.2, 0.8), Offset(0.75, 0.8)],
    // 7 dots
    [Offset(0.2, 0.15), Offset(0.75, 0.15), Offset(0.2, 0.45), Offset(0.75, 0.45), Offset(0.2, 0.75), Offset(0.75, 0.75), Offset(0.5, 0.9)],
    // 8 dots
    [Offset(0.15, 0.15), Offset(0.5, 0.15), Offset(0.85, 0.15), Offset(0.15, 0.5), Offset(0.85, 0.5), Offset(0.15, 0.85), Offset(0.5, 0.85), Offset(0.85, 0.85)],
    // 9 dots
    [Offset(0.15, 0.15), Offset(0.5, 0.15), Offset(0.85, 0.15), Offset(0.15, 0.5), Offset(0.5, 0.5), Offset(0.85, 0.5), Offset(0.15, 0.85), Offset(0.5, 0.85), Offset(0.85, 0.85)],
  ];

  int get _dotCount => widget.question.operands.isNotEmpty
      ? (widget.question.operands[0] as int).clamp(1, 9)
      : widget.question.correctAnswer.clamp(1, 9);

  List<Offset> get _positions {
    final idx = (_dotCount - 1).clamp(0, _dotPositions.length - 1);
    return _dotPositions[idx];
  }

  @override
  void initState() {
    super.initState();
    _speakInstruction();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _dotsVisible = false);
        context.read<AudioService>().speak('¿Cuántos puntos viste?');
      }
    });
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 400));
    context.read<AudioService>().speak('¡Mira los puntos y di cuántos hay!');
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _selectAnswer(int answer) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
    });
    context.read<AudioService>().speakNumber(answer);
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onAnswer(answer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInstructionBanner(),
        const SizedBox(height: 16),
        _buildDotCard(),
        const SizedBox(height: 20),
        if (!_dotsVisible) _buildAnswerChoices(),
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
          const Text('👁️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dotsVisible
                  ? '¡Mira los puntos y di cuántos hay!'
                  : '¿Cuántos puntos viste?',
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

  Widget _buildDotCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
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
          if (_dotsVisible) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '¡Rápido!',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                children: _positions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final pos = entry.value;
                  return Positioned(
                    left: pos.dx * 220 - 11,
                    top: pos.dy * 220 - 11,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(delay: Duration(milliseconds: 60 * i))
                        .fadeIn()
                        .scale(begin: const Offset(0.3, 0.3)),
                  );
                }).toList(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '¿Cuántos\npuntos viste?',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildAnswerChoices() {
    return Column(
      children: [
        Text(
          'Elige la respuesta correcta:',
          style: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: widget.question.choices.map((choice) {
            final isSelected = _selectedAnswer == choice;
            final isCorrect = choice == widget.question.correctAnswer;
            final showResult = _answered && isSelected;

            Color bgColor = Colors.white;
            Color borderColor = const Color(0xFFDDDDDD);
            Color textColor = AppColors.textPrimary;

            if (showResult) {
              bgColor = isCorrect ? AppColors.success : AppColors.error;
              borderColor = bgColor;
              textColor = Colors.white;
            }

            return GestureDetector(
              onTap: () => _selectAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: bgColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$choice',
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    if (!isSelected)
                      Text(
                        '●' * choice.clamp(0, 9),
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppColors.textHint,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    delay: Duration(
                      milliseconds:
                          100 * widget.question.choices.indexOf(choice),
                    ),
                  )
                  .fadeIn(
                    delay: Duration(
                      milliseconds:
                          100 * widget.question.choices.indexOf(choice),
                    ),
                  ),
            );
          }).toList(),
        ),
      ],
    ).animate().slideY(begin: 0.3).fadeIn();
  }
}
