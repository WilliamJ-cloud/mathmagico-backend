import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class ConteoActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const ConteoActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<ConteoActivity> createState() => _ConteoActivityState();
}

class _ConteoActivityState extends State<ConteoActivity> {
  late List<bool> _tapped;
  int _tapCount = 0;
  bool _answered = false;
  int? _selectedAnswer;

  int get _totalObjects => widget.question.correctAnswer;
  String get _emoji =>
      widget.question.emoji1 ?? '🐶';

  @override
  void initState() {
    super.initState();
    _tapped = List.generate(_totalObjects, (_) => false);
    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 500));
    context.read<AudioService>().speak(
      'Toca cada ${_getAnimalName()} para contarlo. Toca uno por uno.',
    );
  }

  String _getAnimalName() {
    const names = {
      '🐶': 'perrito',
      '🐱': 'gatito',
      '🐸': 'ranita',
      '🦋': 'mariposa',
      '⭐': 'estrella',
    };
    return names[_emoji] ?? 'objeto';
  }

  void _tapObject(int index) async {
    if (_answered) return;

    // Vibración táctil suave
    HapticFeedback.lightImpact();

    if (!_tapped[index]) {
      setState(() {
        _tapped[index] = true;
        _tapCount++;
      });

      // Leer el número en voz alta
      await context.read<AudioService>().speakNumber(_tapCount);
      context.read<AudioService>().playTapSound();

      // Todos los objetos contados
      if (_tapCount == _totalObjects) {
        await Future.delayed(const Duration(milliseconds: 500));
        context.read<AudioService>().speak(
          'Muy bien, contaste $_totalObjects. Ahora elige el número correcto.',
        );
      }
    }
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

  void _resetCount() {
    setState(() {
      _tapped = List.generate(_totalObjects, (_) => false);
      _tapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instrucción con mascota
        _buildInstruction(),
        const SizedBox(height: 16),

        // Área de objetos para tocar
        _buildTapArea(),
        const SizedBox(height: 16),

        // Contador visual
        _buildCounter(),
        const SizedBox(height: 20),

        // Botones de respuesta
        if (_tapCount > 0) _buildAnswerChoices(),
      ],
    );
  }

  Widget _buildInstruction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('🦉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¡Toca cada $_emoji para contarlo!',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTapArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: AppColors.success.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Toca cada objeto:',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(_totalObjects, (index) {
              final isTapped = _tapped[index];
              return GestureDetector(
                onTap: () => _tapObject(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isTapped
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isTapped
                          ? AppColors.success
                          : Colors.grey.shade300,
                      width: 2.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        _emoji,
                        style: TextStyle(
                          fontSize: 28,
                          color: isTapped
                              ? null
                              : null,
                        ),
                      ),
                      if (isTapped)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).animate(
                  delay: Duration(milliseconds: 60 * index),
                  effects: [
                    if (isTapped)
                      const ScaleEffect(
                        begin: Offset(1.3, 1.3),
                        end: Offset(1.0, 1.0),
                        duration: Duration(milliseconds: 200),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Botón para reiniciar el conteo
          TextButton.icon(
            onPressed: _resetCount,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'Empezar de nuevo',
              style: GoogleFonts.nunito(fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _tapCount == _totalObjects
            ? AppColors.successLight
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _tapCount == _totalObjects
              ? AppColors.success
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Contaste: ',
            style: GoogleFonts.nunito(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '$_tapCount',
            style: GoogleFonts.nunito(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: _tapCount == _totalObjects
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),
          if (_tapCount == _totalObjects)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('🎉', style: TextStyle(fontSize: 32)),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerChoices() {
    return Column(
      children: [
        Text(
          '¿Cuántos hay en total?',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: widget.question.choices.map((choice) {
            final isSelected = _selectedAnswer == choice;

            return GestureDetector(
              onTap: () => _selectAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: 2.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$choice',
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().slideY(begin: 0.3).fadeIn();
  }
}