import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class SumaVisualActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;
  final bool isSubtraction;

  const SumaVisualActivity({
    super.key,
    required this.question,
    required this.onAnswer,
    this.isSubtraction = false,
  });

  @override
  State<SumaVisualActivity> createState() => _SumaVisualActivityState();
}

class _SumaVisualActivityState extends State<SumaVisualActivity> {
  int? _selectedAnswer;
  bool _answered = false;

  int get _num1 => widget.question.operands.isNotEmpty
      ? widget.question.operands[0] as int
      : 0;
  int get _num2 => widget.question.operands.length > 1
      ? widget.question.operands[1] as int
      : 0;
  String get _emoji1 => widget.question.emoji1 ?? '🍎';
  String get _emoji2 => widget.question.emoji2 ?? '🍊';
  String get _operator => widget.isSubtraction ? '−' : '+';

  void _selectAnswer(int answer) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
    });
    // Leer el número seleccionado
    context.read<AudioService>().speakNumber(answer);
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onAnswer(answer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pregunta visual
        _buildVisualQuestion(),
        const SizedBox(height: 24),
        // Opciones de respuesta
        _buildAnswerChoices(),
      ],
    );
  }

  Widget _buildVisualQuestion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
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
          Text(
            widget.question.questionText,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Representación visual
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Grupo 1
              _buildEmojiGroup(_num1, _emoji1),

              const SizedBox(width: 16),

              // Operador
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.isSubtraction
                      ? AppColors.secondary
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _operator,
                    style: GoogleFonts.nunito(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Grupo 2
              _buildEmojiGroup(_num2, _emoji2),
            ],
          ),

          const SizedBox(height: 16),

          // Expresión numérica
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_num1 $_operator $_num2 = ?',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildEmojiGroup(int count, String emoji) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.15), width: 1.5),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: List.generate(
          count,
          (i) => Text(
            emoji,
            style: const TextStyle(fontSize: 22),
          )
              .animate(delay: Duration(milliseconds: 60 * i))
              .fadeIn()
              .scale(begin: const Offset(0.3, 0.3)),
        ),
      ),
    );
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
              if (isCorrect) {
                bgColor = AppColors.success;
                borderColor = AppColors.success;
                textColor = Colors.white;
              } else {
                bgColor = AppColors.error;
                borderColor = AppColors.error;
                textColor = Colors.white;
              }
            } else if (isSelected) {
              bgColor = AppColors.primary;
              borderColor = AppColors.primary;
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
                    // Mostrar emojis de conteo (apoyo visual)
                    if (!isSelected)
                      Text(
                        _getCountEmojis(choice),
                        style: const TextStyle(fontSize: 8),
                      ),
                  ],
                ),
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
                    delay: Duration(
                        milliseconds: 100 * widget.question.choices.indexOf(choice)),
                  ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Representación visual del número (puntos) para apoyo en discalculia
  String _getCountEmojis(int count) {
    if (count > 10) return '';
    return '●' * count;
  }
}