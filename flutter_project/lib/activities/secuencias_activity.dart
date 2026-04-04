import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';

class SecuenciasActivity extends StatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const SecuenciasActivity({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<SecuenciasActivity> createState() => _SecuenciasActivityState();
}

class _SecuenciasActivityState extends State<SecuenciasActivity> {
  late List<int> _shuffled;
  late List<int?> _slots; // Posiciones donde el niño coloca los números
  int? _selectedNumber;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    // Los operands contienen la secuencia desordenada
    _shuffled = List<int>.from(
      widget.question.operands.map((e) => e as int),
    );
    _slots = List.filled(_shuffled.length, null);
    _speakInstruction();
  }

  Future<void> _speakInstruction() async {
    await Future.delayed(const Duration(milliseconds: 500));
    context.read<AudioService>().speak(
      'Ordena los números del más pequeño al más grande. '
      'Toca un número y luego toca el lugar donde quieres ponerlo.',
    );
  }

  void _selectNumber(int number) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    setState(() {
      // Si ya estaba seleccionado, deseleccionar
      if (_selectedNumber == number) {
        _selectedNumber = null;
      } else {
        _selectedNumber = number;
      }
    });
    context.read<AudioService>().speakNumber(number);
  }

  void _placeInSlot(int slotIndex) {
    if (_answered || _selectedNumber == null) return;

    // Si el slot ya tiene un número, intercambiar
    final existing = _slots[slotIndex];

    setState(() {
      _slots[slotIndex] = _selectedNumber;
      if (existing != null) {
        // Devolver el número que estaba al área de selección
        final idx = _shuffled.indexOf(_selectedNumber!);
        if (idx >= 0) _shuffled[idx] = existing;
      } else {
        _shuffled.remove(_selectedNumber);
      }
      _selectedNumber = null;
    });

    // Verificar si todos los slots están llenos
    if (!_slots.contains(null)) {
      _checkAnswer();
    }
  }

  void _returnToPool(int slotIndex) {
    if (_answered) return;
    final number = _slots[slotIndex];
    if (number == null) return;
    setState(() {
      _slots[slotIndex] = null;
      if (!_shuffled.contains(number)) {
        _shuffled.add(number);
      }
    });
  }

  void _checkAnswer() async {
    // Verificar si el orden es correcto (ascendente)
    bool isCorrect = true;
    for (int i = 0; i < _slots.length - 1; i++) {
      if ((_slots[i] ?? 0) > (_slots[i + 1] ?? 0)) {
        isCorrect = false;
        break;
      }
    }

    setState(() => _answered = true);

    final audio = context.read<AudioService>();
    if (isCorrect) {
      await audio.speak('¡Perfecto! Ordenaste los números correctamente.');
    } else {
      await audio.speak('Casi. El orden correcto es de menor a mayor.');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    widget.onAnswer(isCorrect ? widget.question.correctAnswer : -1);
  }

  bool get _isSlotCorrect => !_slots.contains(null) && _checkOrderCorrect();

  bool _checkOrderCorrect() {
    for (int i = 0; i < _slots.length - 1; i++) {
      if ((_slots[i] ?? 0) > (_slots[i + 1] ?? 0)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Instrucción
        _buildInstruction(),
        const SizedBox(height: 20),

        // Área de slots (donde se ordenan)
        _buildSlotsArea(),
        const SizedBox(height: 20),

        // Números disponibles para seleccionar
        if (_shuffled.isNotEmpty) _buildNumberPool(),

        const SizedBox(height: 16),

        // Botón verificar (si todos los slots están llenos)
        if (!_slots.contains(null) && !_answered) _buildVerifyButton(),
      ],
    );
  }

  Widget _buildInstruction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 2),
      ),
      child: Row(
        children: [
          const Text('🦉', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ordena los números de menor a mayor →',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsArea() {
    return Column(
      children: [
        Text(
          'Coloca aquí los números en orden:',
          style: GoogleFonts.nunito(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slots.length, (i) {
            final value = _slots[i];
            final hasValue = value != null;

            // Verificar si está en posición correcta
            final sortedList = List<int>.from(
                widget.question.operands.map((e) => e as int))
              ..sort();
            final isCorrectPosition =
                hasValue && _answered && value == sortedList[i];
            final isWrongPosition =
                hasValue && _answered && value != sortedList[i];

            return GestureDetector(
              onTap: hasValue
                  ? () => _returnToPool(i)
                  : _selectedNumber != null
                      ? () => _placeInSlot(i)
                      : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 62,
                height: 72,
                decoration: BoxDecoration(
                  color: isCorrectPosition
                      ? AppColors.successLight
                      : isWrongPosition
                          ? AppColors.errorLight
                          : hasValue
                              ? AppColors.primaryLight.withOpacity(0.2)
                              : _selectedNumber != null
                                  ? AppColors.accent.withOpacity(0.15)
                                  : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrectPosition
                        ? AppColors.success
                        : isWrongPosition
                            ? AppColors.error
                            : hasValue
                                ? AppColors.primary
                                : _selectedNumber != null
                                    ? AppColors.accent
                                    : Colors.grey.shade300,
                    width: 2.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasValue) ...[
                      Text(
                        '$value',
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: isCorrectPosition
                              ? AppColors.success
                              : isWrongPosition
                                  ? AppColors.error
                                  : AppColors.primary,
                        ),
                      ),
                      if (_answered)
                        Icon(
                          isCorrectPosition ? Icons.check : Icons.close,
                          color: isCorrectPosition
                              ? AppColors.success
                              : AppColors.error,
                          size: 16,
                        ),
                    ] else
                      Column(
                        children: [
                          Text(
                            '${i + 1}°',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.add_circle_outline,
                            color: _selectedNumber != null
                                ? AppColors.accent
                                : Colors.grey.shade300,
                            size: 22,
                          ),
                        ],
                      ),
                  ],
                ),
              ).animate(
                effects: hasValue
                    ? [
                        const ScaleEffect(
                          begin: Offset(0.85, 0.85),
                          end: Offset(1.0, 1.0),
                          duration: Duration(milliseconds: 200),
                        )
                      ]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        // Flecha indicadora
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'menor',
              style: GoogleFonts.nunito(
                  fontSize: 12, color: AppColors.textHint),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward,
                  color: AppColors.textHint, size: 16),
            ),
            Text(
              'mayor',
              style: GoogleFonts.nunito(
                  fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberPool() {
    return Column(
      children: [
        Text(
          _selectedNumber != null
              ? 'Número seleccionado: $_selectedNumber  →  toca un espacio arriba'
              : 'Toca un número para seleccionarlo:',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: _selectedNumber != null
                ? AppColors.primary
                : AppColors.textSecondary,
            fontWeight: _selectedNumber != null
                ? FontWeight.w700
                : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _shuffled.map((number) {
            final isSelected = _selectedNumber == number;
            return GestureDetector(
              onTap: () => _selectNumber(number),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().slideY(begin: 0.2).fadeIn();
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _checkAnswer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          '✓  Verificar orden',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().slideY(begin: 0.3).fadeIn();
  }
}