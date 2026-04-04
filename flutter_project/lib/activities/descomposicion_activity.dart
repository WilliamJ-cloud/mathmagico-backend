import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class DescomposicionActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const DescomposicionActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<DescomposicionActivity> createState() => _DescomposicionActivityState();
}

class _DescomposicionActivityState extends State<DescomposicionActivity> {
  int? _selectedAnswer;
  bool _answered = false;

  /// operands[0] = total (e.g. 7)
  /// operands[1] = known part (e.g. 3)
  /// correctAnswer = missing part (e.g. 4)
  int get _total => widget.question.operands.isNotEmpty
      ? widget.question.operands[0] as int
      : 0;

  int get _knownPart => widget.question.operands.length > 1
      ? widget.question.operands[1] as int
      : 0;

  int get _missingPart => widget.question.correctAnswer;

  String get _emoji1 => widget.question.emoji1 ?? '🍎';
  String get _emoji2 => widget.question.emoji2 ?? '🌟';

  bool get _isCorrect =>
      _selectedAnswer != null &&
      _selectedAnswer == widget.question.correctAnswer;

  @override
  void initState() {
    super.initState();
    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 400));
    context.read<AudioService>().speak(
          '$_knownPart más qué número es igual a $_total.',
        );
  }

  void _selectAnswer(int answer) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedAnswer = answer;
      _answered = true;
    });
    context.read<AudioService>().speakNumber(answer);
    Future.delayed(const Duration(milliseconds: 350), () {
      widget.onAnswer(answer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInstructionBanner(),
        const SizedBox(height: 16),
        _buildVisualCard(),
        const SizedBox(height: 20),
        _buildAnswerChoices(),
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
              '¿Qué número falta? $_knownPart + ? = $_total',
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

  Widget _buildVisualCard() {
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
          // Visual emoji groups: [emoji x knownPart] + [? x missingPart] = total
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Known group
              _buildEmojiGroup(
                count: _knownPart,
                emoji: _emoji1,
                color: AppColors.primary.withOpacity(0.12),
                borderColor: AppColors.primary.withOpacity(0.3),
              ),

              const SizedBox(width: 10),

              // Plus symbol
              _buildOperatorCircle('+', AppColors.primary),

              const SizedBox(width: 10),

              // Unknown group
              _buildMissingGroup(),

              const SizedBox(width: 10),

              // Equals symbol
              _buildOperatorCircle('=', AppColors.textSecondary),

              const SizedBox(width: 10),

              // Total
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$_total',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Equation text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_knownPart + ',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _answered && _isCorrect
                        ? AppColors.success
                        : _answered && !_isCorrect
                            ? AppColors.error
                            : AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _answered
                          ? Colors.transparent
                          : AppColors.primary.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _answered ? '$_selectedAnswer' : '?',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _answered ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                Text(
                  ' = $_total',
                  style: GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildEmojiGroup({
    required int count,
    required String emoji,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100, minWidth: 52),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: List.generate(
          count.clamp(0, 12),
          (i) => Text(
            emoji,
            style: const TextStyle(fontSize: 20),
          )
              .animate(delay: Duration(milliseconds: 50 * i))
              .fadeIn()
              .scale(begin: const Offset(0.3, 0.3)),
        ),
      ),
    );
  }

  Widget _buildMissingGroup() {
    final revealMissing = _answered && _isCorrect;
    return Container(
      constraints: const BoxConstraints(maxWidth: 100, minWidth: 52),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: revealMissing
            ? AppColors.success.withOpacity(0.12)
            : AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: revealMissing
              ? AppColors.success.withOpacity(0.4)
              : AppColors.accent.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: List.generate(
          _missingPart.clamp(0, 12),
          (i) => revealMissing
              ? Text(
                  _emoji2,
                  style: const TextStyle(fontSize: 20),
                )
                  .animate(delay: Duration(milliseconds: 60 * i))
                  .fadeIn()
                  .scale(begin: const Offset(0.3, 0.3))
              : Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                )
                  .animate(delay: Duration(milliseconds: 50 * i))
                  .fadeIn(),
        ),
      ),
    );
  }

  Widget _buildOperatorCircle(String symbol, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Center(
        child: Text(
          symbol,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerChoices() {
    return Column(
      children: [
        Text(
          'Elige el número que falta:',
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
            } else if (_answered && isCorrect) {
              bgColor = AppColors.successLight;
              borderColor = AppColors.success;
              textColor = AppColors.success;
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
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
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
