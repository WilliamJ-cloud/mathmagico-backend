import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class CompararActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const CompararActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<CompararActivity> createState() => _CompararActivityState();
}

class _CompararActivityState extends State<CompararActivity> {
  int? _selectedAnswer;
  bool _answered = false;

  int get _num1 => widget.question.operands.isNotEmpty
      ? widget.question.operands[0] as int
      : 0;
  int get _num2 => widget.question.operands.length > 1
      ? widget.question.operands[1] as int
      : 0;
  String get _emoji => widget.question.emoji1 ?? '⭐';

  String _getSymbol(int code) {
    switch (code) {
      case 1: return '<';
      case 2: return '=';
      case 3: return '>';
      default: return '?';
    }
  }

  void _selectAnswer(int code) {
    if (_answered) return;
    setState(() {
      _selectedAnswer = code;
      _answered = true;
    });
    context.read<AudioService>().speak(
      '$_num1 ${_getSymbol(code)} $_num2',
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.onAnswer(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildQuestionCard(),
        const SizedBox(height: 20),
        Text(
          'Elige el símbolo correcto:',
          style: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSymbolButtons(),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.question.questionText,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNumberGroup(_num1, AppColors.secondary),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _answered
                      ? (_selectedAnswer == widget.question.correctAnswer
                          ? AppColors.success
                          : AppColors.error)
                      : AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _answered
                        ? Colors.transparent
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _answered
                        ? _getSymbol(_selectedAnswer ?? 0)
                        : '?',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _answered ? Colors.white : AppColors.textHint,
                    ),
                  ),
                ),
              ),
              _buildNumberGroup(_num2, AppColors.primary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildNumberGroup(int count, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Center(
            child: Text(
              '$count',
              style: GoogleFonts.nunito(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            alignment: WrapAlignment.center,
            children: List.generate(
              count.clamp(0, 10),
              (i) => Text(_emoji, style: const TextStyle(fontSize: 14))
                  .animate(delay: Duration(milliseconds: 40 * i))
                  .fadeIn(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolButtons() {
    final symbols = [
      {
        'code': 1,
        'symbol': '<',
        'label': 'Menor que',
        'color': AppColors.secondary
      },
      {
        'code': 2,
        'symbol': '=',
        'label': 'Igual',
        'color': AppColors.textSecondary
      },
      {
        'code': 3,
        'symbol': '>',
        'label': 'Mayor que',
        'color': AppColors.primary
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: symbols.map((s) {
        final code = s['code'] as int;
        final symbol = s['symbol'] as String;
        final label = s['label'] as String;
        final color = s['color'] as Color;
        final isSelected = _selectedAnswer == code;
        final isCorrect = code == widget.question.correctAnswer;

        Color bgColor = Colors.white;
        Color borderColor = color.withOpacity(0.3);
        Color textColor = color;

        if (_answered && isSelected) {
          bgColor = isCorrect ? AppColors.success : AppColors.error;
          borderColor = bgColor;
          textColor = Colors.white;
        } else if (_answered && isCorrect) {
          bgColor = AppColors.successLight;
          borderColor = AppColors.success;
          textColor = AppColors.success;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => _selectAnswer(code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 86,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 2.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    symbol,
                    style: GoogleFonts.nunito(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: _answered && isSelected
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().slideY(begin: 0.3).fadeIn();
  }
}
