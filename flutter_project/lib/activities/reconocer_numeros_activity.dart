import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class ReconocerNumerosActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const ReconocerNumerosActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<ReconocerNumerosActivity> createState() =>
      _ReconocerNumerosActivityState();
}

class _ReconocerNumerosActivityState
    extends State<ReconocerNumerosActivity>
    with SingleTickerProviderStateMixin {
  int? _selectedAnswer;
  bool _answered = false;
  late AnimationController _pulseController;

  // El número a reconocer está en operands[0]
  int get _targetNumber => widget.question.operands[0] as int;

  final List<Color> _numberColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.success,
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
  ];

  Color get _numberColor =>
      _numberColors[_targetNumber % _numberColors.length];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _speakNumber();
  }

  Future<void> _speakNumber() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final audio = context.read<AudioService>();
    await audio.speak('¿Qué número es este?');
    await Future.delayed(const Duration(milliseconds: 800));
    await audio.speakNumber(_targetNumber);
  }

  void _selectAnswer(int answer) {
    if (_answered) return;
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
        // Número grande visual
        _buildBigNumber(),
        const SizedBox(height: 24),
        // Pregunta
        Text(
          widget.question.questionText,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Botón TTS
        TextButton.icon(
          onPressed: _speakNumber,
          icon: const Icon(Icons.volume_up, color: AppColors.primary),
          label: Text(
            'Escuchar otra vez',
            style: GoogleFonts.nunito(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Opciones de respuesta
        _buildChoices(),
      ],
    );
  }

  Widget _buildBigNumber() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        final scale = 1.0 + (_pulseController.value * 0.04);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: _numberColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _numberColor.withOpacity(0.3),
            width: 2.5,
          ),
        ),
        child: Column(
          children: [
            // Número gigante
            Text(
              '$_targetNumber',
              style: GoogleFonts.nunito(
                fontSize: 120,
                fontWeight: FontWeight.w800,
                color: _numberColor,
                height: 1.0,
              ),
            ).animate().fadeIn().scale(
                  begin: const Offset(0.5, 0.5),
                  curve: Curves.elasticOut,
                  duration: 800.ms,
                ),

            const SizedBox(height: 8),

            // Representación en puntos (apoyo visual para discalculia)
            if (_targetNumber <= 10)
              _buildDotRepresentation(_targetNumber, _numberColor),

            const SizedBox(height: 8),

            // Nombre del número en letras
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _numberColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _numberToWord(_targetNumber),
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _numberColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Representación de puntos tipo dado (patrón de subitización)
  Widget _buildDotRepresentation(int count, Color color) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(
            count,
            (i) => Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ).animate(delay: Duration(milliseconds: 50 * i)).fadeIn().scale(
                  begin: const Offset(0, 0),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Column(
      children: [
        Text(
          'Elige el número correcto:',
          style: GoogleFonts.nunito(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: widget.question.choices.map((choice) {
            final isSelected = _selectedAnswer == choice;
            final isCorrect = choice == widget.question.correctAnswer;

            Color bgColor = Colors.white;
            Color borderColor = Colors.grey.shade300;
            Color textColor = AppColors.textPrimary;

            if (_answered && isSelected) {
              bgColor = isCorrect ? AppColors.success : AppColors.error;
              borderColor = bgColor;
              textColor = Colors.white;
            } else if (_answered && isCorrect) {
              // Mostrar la correcta aunque no la hayan seleccionado
              bgColor = AppColors.successLight;
              borderColor = AppColors.success;
              textColor = AppColors.success;
            }

            return GestureDetector(
              onTap: () => _selectAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: isSelected && !_answered
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$choice',
                        style: GoogleFonts.nunito(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      // Mini dots debajo de cada opción
                      if (choice <= 10 && !_answered)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            choice > 5 ? 5 : choice,
                            (_) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ).animate(
                delay: Duration(
                  milliseconds:
                      100 * widget.question.choices.indexOf(choice),
                ),
              ).scale(begin: const Offset(0.8, 0.8)).fadeIn(),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _numberToWord(int n) {
    const words = [
      'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco',
      'seis', 'siete', 'ocho', 'nueve', 'diez',
    ];
    if (n >= 0 && n < words.length) return words[n];
    return '$n';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}