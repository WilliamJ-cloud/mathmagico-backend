import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class LineaNumericaActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const LineaNumericaActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<LineaNumericaActivity> createState() => _LineaNumericaActivityState();
}

class _LineaNumericaActivityState extends State<LineaNumericaActivity> {
  int? _tappedPosition;
  bool _answered = false;

  int get _numberToPlace => widget.question.operands.isNotEmpty
      ? widget.question.operands[0] as int
      : widget.question.correctAnswer;

  int get _maxNumber => widget.question.operands.length > 1
      ? widget.question.operands[1] as int
      : 10;

  bool get _isCorrect =>
      _tappedPosition != null &&
      _tappedPosition == widget.question.correctAnswer;

  @override
  void initState() {
    super.initState();
    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 400));
    context.read<AudioService>().speak(
          'Coloca el número $_numberToPlace en la línea numérica.',
        );
  }

  void _tapPosition(int value) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _tappedPosition = value;
      _answered = true;
    });
    context.read<AudioService>().speakNumber(value);
    Future.delayed(const Duration(milliseconds: 400), () {
      widget.onAnswer(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInstructionBanner(),
        const SizedBox(height: 20),
        _buildNumberCard(),
        const SizedBox(height: 24),
        _buildNumberLine(),
        if (_answered) ...[
          const SizedBox(height: 16),
          _buildResultMessage(),
        ],
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
          const Text('🦉', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¿Dónde va el número en la línea?',
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

  Widget _buildNumberCard() {
    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Coloca el número',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_numberToPlace',
                    style: GoogleFonts.nunito(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeInOut,
                  ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildNumberLine() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.success.withOpacity(0.25),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Toca el lugar correcto:',
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_maxNumber + 1, (i) {
                final isTarget = _answered && _tappedPosition == i;
                final isCorrectPos = i == widget.question.correctAnswer;
                final showCorrect = _answered && isCorrectPos;

                Color bgColor;
                Color borderColor;
                Color textColor;

                if (isTarget && isCorrectPos) {
                  bgColor = AppColors.success;
                  borderColor = AppColors.success;
                  textColor = Colors.white;
                } else if (isTarget && !isCorrectPos) {
                  bgColor = AppColors.error;
                  borderColor = AppColors.error;
                  textColor = Colors.white;
                } else if (showCorrect && !isTarget) {
                  bgColor = AppColors.successLight;
                  borderColor = AppColors.success;
                  textColor = AppColors.success;
                } else {
                  bgColor = Colors.white;
                  borderColor = AppColors.primary.withOpacity(0.3);
                  textColor = AppColors.textPrimary;
                }

                final isActive = !_answered;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: isActive ? () => _tapPosition(i) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: borderColor,
                          width: 2.5,
                        ),
                        boxShadow: (isTarget || showCorrect)
                            ? [
                                BoxShadow(
                                  color: bgColor.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                      ),
                    )
                        .animate(
                          target: (isTarget && isCorrectPos) ? 1 : 0,
                        )
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.15, 1.15),
                          duration: const Duration(milliseconds: 300),
                        ),
                  )
                      .animate(delay: Duration(milliseconds: 40 * i))
                      .slideY(begin: 0.4)
                      .fadeIn(),
                );
              }),
            ),
          ),
          // Number line bar below circles
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3).fadeIn();
  }

  Widget _buildResultMessage() {
    final correct = _isCorrect;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: correct ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: correct ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            correct ? '🎉' : '💪',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 10),
          Text(
            correct
                ? '¡Correcto! El $_numberToPlace va aquí.'
                : 'El $_numberToPlace va en el ${widget.question.correctAnswer}.',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: correct ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3).fadeIn();
  }
}
