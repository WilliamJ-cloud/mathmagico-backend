import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../config/constants.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/mascot_widget.dart';
import '../activities/suma_visual_activity.dart';
import '../activities/conteo_activity.dart';
import '../activities/comparar_activity.dart';
import '../activities/secuencias_activity.dart';
import '../activities/reconocer_numeros_activity.dart';
import '../activities/subitizacion_activity.dart';
import '../activities/linea_numerica_activity.dart';
import '../activities/descomposicion_activity.dart';
import '../activities/trazar_numeros_activity.dart';

class ActivityScreen extends StatefulWidget {
  final ActivityModel activity;

  const ActivityScreen({super.key, required this.activity});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late ConfettiController _confettiController;
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  int _correctAnswers = 0;
  int _hintsUsed = 0;
  bool _isLoading = true;
  bool _showFeedback = false;
  bool _lastAnswerCorrect = false;
  bool _activityComplete = false;
  final List<QuestionResult> _results = [];
  final List<String> _newAchievements = [];
  final _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _loadQuestions();
    _stopwatch.start();
  }

  Future<void> _loadQuestions() async {
    final user = context.read<UserProvider>().user;
    final apiService = context.read<ApiService>();
    final audioService = context.read<AudioService>();

    final response = await apiService.getQuestions(
      activityType: widget.activity.id,
      difficulty: widget.activity.difficulty == Difficulty.easy
          ? AppConstants.difficultyEasy
          : widget.activity.difficulty == Difficulty.medium
              ? AppConstants.difficultyMedium
              : AppConstants.difficultyHard,
      userId: user?.id ?? 'guest',
      count: AppConstants.maxQuestionsPerSession,
    );

    if (mounted) {
      List<QuestionModel> parsed = [];
      if (response != null) {
        try {
          final list = response['questions'] ?? response['data'];
          if (list is List) {
            parsed = list
                .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
                .toList();
          }
        } catch (_) {}
      }

      // These activity types have no backend question generator yet —
      // always use the offline set so the API's generic sum questions
      // don't corrupt the operand semantics each activity expects.
      const needOffline = {
        ActivityType.subitizacion,
        ActivityType.lineaNumerica,
        ActivityType.descomposicion,
        ActivityType.trazarNumeros,
        ActivityType.conteo,
      };
      final forceOffline = needOffline.contains(widget.activity.type);

      setState(() {
        _questions = (parsed.isEmpty || forceOffline)
            ? _getOfflineQuestions()
            : parsed;
        _isLoading = false;
      });
      // Leer instrucción en voz alta
      await audioService.speakInstruction(widget.activity.id);
    }
  }

  void _onAnswer(int answer, int correctAnswer, String questionId) async {
    _stopwatch.stop();
    final isCorrect = answer == correctAnswer;
    final audioService = context.read<AudioService>();

    // Guardar resultado de esta pregunta
    _results.add(QuestionResult(
      questionId: questionId,
      userAnswer: answer,
      correctAnswer: correctAnswer,
      isCorrect: isCorrect,
      hintsUsed: _hintsUsed,
    ));

    setState(() {
      _lastAnswerCorrect = isCorrect;
      _showFeedback = true;
      if (isCorrect) _correctAnswers++;
      _hintsUsed = 0;
    });

    // Sonido y voz
    if (isCorrect) {
      audioService.playCorrectSound();
      await audioService.speakCorrect();
      if (_currentIndex == _questions.length - 1) {
        // Última pregunta correcta
        _confettiController.play();
        audioService.playCelebration();
      }
    } else {
      audioService.playIncorrectSound();
      await audioService.speakIncorrect();
    }

    // Avanzar después de un momento
    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _showFeedback = false;
        });
        _stopwatch
          ..reset()
          ..start();
      } else {
        _completeActivity();
      }
    }
  }

  // Maps activity id → skillLevels key used in UserModel
  static const _skillMap = {
    'suma_visual': 'suma',
    'resta_visual': 'resta',
    'conteo': 'conteo',
    'comparar': 'comparar',
    'secuencias': 'secuencias',
    'reconocer_numeros': 'reconocer',
    'subitizacion': 'conteo',
    'linea_numerica': 'secuencias',
    'descomposicion': 'suma',
    'trazar_numeros': 'reconocer',
  };

  void _completeActivity() async {
    _stopwatch.stop();
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    final isPerfect = _correctAnswers == _questions.length;
    final accuracy = _correctAnswers / _questions.length;
    final pointsEarned = _correctAnswers * AppConstants.pointsPerCorrectAnswer +
        (isPerfect ? AppConstants.bonusPoints : 0);
    final totalHints = _results.fold(0, (sum, r) => sum + r.hintsUsed);
    final totalSeconds = _stopwatch.elapsed.inSeconds;

    final result = ActivityResult(
      activityId: widget.activity.id,
      userId: user.id,
      totalQuestions: _questions.length,
      correctAnswers: _correctAnswers,
      pointsEarned: pointsEarned,
      timeTaken: _stopwatch.elapsed,
      questionResults: _results,
      completedAt: DateTime.now(),
    );

    // Guardar local
    await StorageService.instance.saveSession(result);

    // Enviar al backend (no bloquea la UI si falla)
    final apiResult = await context.read<ApiService>().submitActivityResult(result.toJson());
    if (apiResult == null || apiResult['error'] == true) {
      debugPrint('⚠️ Session not synced to backend: ${apiResult?['detail']}');
    }

    // ── Actualizar habilidades ───────────────────────────
    final skillKey = _skillMap[widget.activity.id];
    final skillIncrement = (accuracy * 10).round(); // 0–10 pts por sesión

    final userProv = context.read<UserProvider>();
    userProv.addPoints(pointsEarned);
    userProv.recordToday(); // ← marca este día como practicado y guarda
    if (skillKey != null) {
      userProv.updateSkill(skillKey, skillIncrement);
      context.read<ProgressProvider>().updateSkill(skillKey, accuracy);
    }

    // ── Comprobar y otorgar logros ───────────────────────
    final earned = user.achievements; // snapshot antes de cualquier addAchievement
    final newAch = <String>[];

    void tryUnlock(String id, bool condition) {
      if (condition && !earned.contains(id)) {
        userProv.addAchievement(id);
        newAch.add(id);
      }
    }

    tryUnlock('cien_puntos',
        (user.totalPoints + pointsEarned) >= 100);
    tryUnlock('sin_pistas', totalHints == 0);
    tryUnlock('velocista', totalSeconds > 0 && totalSeconds < 120);
    tryUnlock('primer_suma', widget.activity.id == 'suma_visual');
    tryUnlock('contador_experto',
        isPerfect && widget.activity.id == 'conteo');
    tryUnlock('maestro_comparacion',
        isPerfect && widget.activity.id == 'comparar');
    tryUnlock('orden_perfecto',
        isPerfect && widget.activity.id == 'secuencias');
    tryUnlock('numero_maestro',
        isPerfect && widget.activity.id == 'reconocer_numeros');

    setState(() {
      _activityComplete = true;
      _newAchievements
        ..clear()
        ..addAll(newAch);
    });

    final audioService = context.read<AudioService>();
    if (newAch.isNotEmpty) {
      _confettiController.play();
      audioService.playUnlockSound();
    } else if (isPerfect) {
      _confettiController.play();
      audioService.playCelebration();
    }
  }

  Future<void> _getHint() async {
    setState(() => _hintsUsed++);
    final currentQ = _questions[_currentIndex];
    final audioService = context.read<AudioService>();

    if (currentQ.hint != null) {
      await audioService.speak(currentQ.hint!);
    } else {
      await audioService.speak(AppConstants.hintMessages[0]);
    }
  }

  Widget _buildCurrentActivity() {
    if (_questions.isEmpty) return const SizedBox();
    final q = _questions[_currentIndex];

    switch (widget.activity.type) {
      case ActivityType.sumaVisual:
        return SumaVisualActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.conteo:
        return ConteoActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.comparar:
        return CompararActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.secuencias:
        return SecuenciasActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.reconocerNumeros:
        return ReconocerNumerosActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.restaVisual:
        return SumaVisualActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
          isSubtraction: true,
        );
      case ActivityType.subitizacion:
        return SubitizacionActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.lineaNumerica:
        return LineaNumericaActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.descomposicion:
        return DescomposicionActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
      case ActivityType.trazarNumeros:
        return TrazarNumerosActivity(
          question: q,
          onAnswer: (ans) => _onAnswer(ans, q.correctAnswer, q.id),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppColors.primary,
                AppColors.accent,
                AppColors.success,
                AppColors.secondary,
              ],
              numberOfParticles: 40,
            ),
          ),

          SafeArea(
            child: _isLoading
                ? _buildLoading()
                : _activityComplete
                    ? _buildCompleteScreen()
                    : _buildActivityContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🦉', style: TextStyle(fontSize: 60)),
          SizedBox(height: 16),
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 12),
          Text('Preparando ejercicios...'),
        ],
      ),
    );
  }

  Widget _buildActivityContent() {
    return Column(
      children: [
        // App bar personalizado
        _buildActivityHeader(),

        // Barra de progreso
        _buildProgressBar(),

        // Contenido de la actividad
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Feedback overlay
                if (_showFeedback) _buildFeedbackBanner(),

                // Actividad actual
                if (!_showFeedback) _buildCurrentActivity(),

                const SizedBox(height: 16),

                // Botón de pista
                if (!_showFeedback && _hintsUsed < AppConstants.maxHintsPerActivity)
                  _buildHintButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityHeader() {
    return Container(
      decoration: BoxDecoration(
        color: widget.activity.color,
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.primary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.activity.emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            widget.activity.title,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _questions.isEmpty
        ? 0.0
        : (_currentIndex + 1) / _questions.length;

    return Column(
      children: [
        Container(
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(99),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pregunta ${_currentIndex + 1} de ${_questions.length}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: AppColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_correctAnswers * AppConstants.pointsPerCorrectAnswer} pts',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _lastAnswerCorrect
            ? AppColors.successLight
            : AppColors.errorLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _lastAnswerCorrect ? AppColors.success : AppColors.error,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(
            _lastAnswerCorrect ? '🎉' : '😊',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lastAnswerCorrect
                  ? '¡Excelente! ¡Lo lograste! +${AppConstants.pointsPerCorrectAnswer} pts'
                  : 'Casi... ¡Inténtalo de nuevo! Tú puedes 💪',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _lastAnswerCorrect
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn();
  }

  Widget _buildHintButton() {
    return TextButton.icon(
      onPressed: _getHint,
      icon: const Text('💡', style: TextStyle(fontSize: 18)),
      label: Text(
        'Necesito una pista',
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primaryLight.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildCompleteScreen() {
    final accuracy = _questions.isEmpty
        ? 0.0
        : _correctAnswers / _questions.length;
    final points = _correctAnswers * AppConstants.pointsPerCorrectAnswer;
    final isPerfect = _correctAnswers == _questions.length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isPerfect ? '🏆' : '🎉',
              style: const TextStyle(fontSize: 80),
            ).animate().scale(begin: const Offset(0.3, 0.3), curve: Curves.elasticOut),

            const SizedBox(height: 16),

            Text(
              isPerfect ? '¡Perfecto!' : '¡Muy bien!',
              style: GoogleFonts.nunito(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 8),

            Text(
              'Respondiste $_correctAnswers de ${_questions.length} correctas',
              style: GoogleFonts.nunito(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatCard('⭐', '$points', 'Puntos'),
                const SizedBox(width: 16),
                _buildStatCard(
                    '🎯',
                    '${(accuracy * 100).toInt()}%',
                    'Precisión'),
                const SizedBox(width: 16),
                _buildStatCard(
                    '✅',
                    '$_correctAnswers',
                    'Correctas'),
              ],
            ).animate().slideY(begin: 0.3).fadeIn(delay: 400.ms),

            const SizedBox(height: 32),

            // Mascota con mensaje
            MascotWidget(
              message: isPerfect
                  ? '¡Eres increíble! Completaste todo perfecto 🌟'
                  : 'Muy buen trabajo. Con más práctica llegarás a la perfección 💪',
            ).animate().fadeIn(delay: 600.ms),

            // ── Logros desbloqueados ─────────────────────
            if (_newAchievements.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '🏆 ¡Nuevo logro desbloqueado!',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._newAchievements.map((id) {
                      const meta = {
                        'cien_puntos':    {'emoji': '⭐', 'title': '¡100 puntos!'},
                        'sin_pistas':     {'emoji': '💪', 'title': 'Sin ayuda'},
                        'velocista':      {'emoji': '⚡', 'title': 'Velocista'},
                        'primer_suma':    {'emoji': '🍎', 'title': 'Primera suma'},
                        'contador_experto': {'emoji': '✋', 'title': 'Contador experto'},
                        'maestro_comparacion': {'emoji': '📏', 'title': 'Maestro comparador'},
                        'orden_perfecto': {'emoji': '🔢', 'title': 'Orden perfecto'},
                        'numero_maestro': {'emoji': '👁️', 'title': 'Maestro de números'},
                      };
                      final m = meta[id] ?? {'emoji': '🏅', 'title': id};
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m['emoji']!, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              m['title']!,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ).animate().scale(begin: const Offset(0.7, 0.7), curve: Curves.elasticOut)
                  .fadeIn(delay: 700.ms),
            ],

            const SizedBox(height: 32),

            // Botones
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                        _correctAnswers = 0;
                        _hintsUsed = 0;
                        _results.clear();
                        _activityComplete = false;
                        _showFeedback = false;
                        _isLoading = true;
                        _questions = [];
                      });
                      _loadQuestions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '¡Jugar otra vez! 🔄',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Volver al inicio 🏠',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().slideY(begin: 0.3).fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Container(
      width: 90,
      padding: const EdgeInsets.all(12),
      decoration: AppStyles.cardDecoration(
          color: AppColors.surfaceVariant),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }


  List<QuestionModel> _getOfflineQuestions() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final type = widget.activity.type;

    // ── Subitización ─────────────────────────────────────
    if (type == ActivityType.subitizacion) {
      return [
        _q(ts, 1, '¿Cuántos puntos ves?', [3], 3, [2,3,4,5], '🔵', null),
        _q(ts, 2, '¿Cuántos puntos ves?', [5], 5, [4,5,6,7], '🔵', null),
        _q(ts, 3, '¿Cuántos puntos ves?', [2], 2, [1,2,3,4], '🔵', null),
        _q(ts, 4, '¿Cuántos puntos ves?', [7], 7, [6,7,8,9], '🔵', null),
        _q(ts, 5, '¿Cuántos puntos ves?', [4], 4, [3,4,5,6], '🔵', null),
      ];
    }

    // ── Línea numérica ────────────────────────────────────
    if (type == ActivityType.lineaNumerica) {
      return [
        _q(ts, 1, '¿Dónde va el 3 en la línea?',  [3,10],  3, [1,2,3,4],  null, null),
        _q(ts, 2, '¿Dónde va el 7 en la línea?',  [7,10],  7, [5,6,7,8],  null, null),
        _q(ts, 3, '¿Dónde va el 1 en la línea?',  [1,10],  1, [1,2,3,4],  null, null),
        _q(ts, 4, '¿Dónde va el 9 en la línea?',  [9,10],  9, [7,8,9,10], null, null),
        _q(ts, 5, '¿Dónde va el 5 en la línea?',  [5,10],  5, [4,5,6,7],  null, null),
      ];
    }

    // ── Descomposición ────────────────────────────────────
    // operands: [total, parte_conocida] — correctAnswer = parte_desconocida
    if (type == ActivityType.descomposicion) {
      return [
        _q(ts, 1, '¿Qué número falta? 3 + ? = 5', [5, 3], 2, [1,2,3,4], '❤️', '⭐'),
        _q(ts, 2, '¿Qué número falta? 2 + ? = 6', [6, 2], 4, [2,3,4,5], '🍎', '🍊'),
        _q(ts, 3, '¿Qué número falta? 4 + ? = 7', [7, 4], 3, [1,2,3,4], '🌟', '🌙'),
        _q(ts, 4, '¿Qué número falta? 1 + ? = 4', [4, 1], 3, [2,3,4,5], '🐶', '🐱'),
        _q(ts, 5, '¿Qué número falta? 5 + ? = 9', [9, 5], 4, [2,3,4,5], '🍓', '🍇'),
      ];
    }

    // ── Trazar números ────────────────────────────────────
    if (type == ActivityType.trazarNumeros) {
      return [
        _q(ts, 1, 'Traza el número 3', [3], 3, [1,2,3,4], null, null),
        _q(ts, 2, 'Traza el número 5', [5], 5, [3,4,5,6], null, null),
        _q(ts, 3, 'Traza el número 1', [1], 1, [1,2,3,4], null, null),
        _q(ts, 4, 'Traza el número 7', [7], 7, [5,6,7,8], null, null),
        _q(ts, 5, 'Traza el número 4', [4], 4, [2,3,4,5], null, null),
      ];
    }

    // ── Conteo ────────────────────────────────────────────
    if (type == ActivityType.conteo) {
      return [
        _q(ts, 1, 'Toca cada objeto para contarlo', [3], 3, [2,3,4,5], '🐶', null),
        _q(ts, 2, 'Toca cada objeto para contarlo', [5], 5, [4,5,6,7], '🐱', null),
        _q(ts, 3, 'Toca cada objeto para contarlo', [4], 4, [3,4,5,6], '🐸', null),
        _q(ts, 4, 'Toca cada objeto para contarlo', [2], 2, [1,2,3,4], '🦋', null),
        _q(ts, 5, 'Toca cada objeto para contarlo', [6], 6, [5,6,7,8], '⭐', null),
      ];
    }

    // ── Reconocer números ─────────────────────────────────
    if (type == ActivityType.reconocerNumeros) {
      return [
        _q(ts, 1, '¿Qué número es este?', [2], 2, [1,2,3,4], null, null),
        _q(ts, 2, '¿Qué número es este?', [5], 5, [4,5,6,7], null, null),
        _q(ts, 3, '¿Qué número es este?', [3], 3, [2,3,4,5], null, null),
        _q(ts, 4, '¿Qué número es este?', [7], 7, [5,6,7,8], null, null),
        _q(ts, 5, '¿Qué número es este?', [1], 1, [1,2,3,4], null, null),
        _q(ts, 6, '¿Qué número es este?', [4], 4, [2,3,4,5], null, null),
        _q(ts, 7, '¿Qué número es este?', [9], 9, [7,8,9,10], null, null),
        _q(ts, 8, '¿Qué número es este?', [6], 6, [4,5,6,7], null, null),
        _q(ts, 9, '¿Qué número es este?', [8], 8, [6,7,8,9], null, null),
        _q(ts, 10, '¿Qué número es este?', [10], 10, [8,9,10,11], null, null),
      ];
    }

    // ── Secuencias ────────────────────────────────────────
    if (type == ActivityType.secuencias) {
      return [
        _q(ts, 1, 'Ordena estos números de menor a mayor:', [3,1,2], 3, [1,2,3], null, null),
        _q(ts, 2, 'Ordena estos números de menor a mayor:', [4,2,3], 4, [2,3,4], null, null),
        _q(ts, 3, 'Ordena estos números de menor a mayor:', [2,4,3], 4, [2,3,4], null, null),
        _q(ts, 4, 'Ordena estos números de menor a mayor:', [5,3,4], 5, [3,4,5], null, null),
        _q(ts, 5, 'Ordena estos números de menor a mayor:', [1,3,2], 3, [1,2,3], null, null),
        _q(ts, 6, 'Ordena estos números de menor a mayor:', [6,4,5], 6, [4,5,6], null, null),
        _q(ts, 7, 'Ordena estos números de menor a mayor:', [3,5,4], 5, [3,4,5], null, null),
        _q(ts, 8, 'Ordena estos números de menor a mayor:', [7,5,6], 7, [5,6,7], null, null),
        _q(ts, 9, 'Ordena estos números de menor a mayor:', [2,1,3], 3, [1,2,3], null, null),
        _q(ts, 10, 'Ordena estos números de menor a mayor:', [8,6,7], 8, [6,7,8], null, null),
      ];
    }

    // ── Comparar ──────────────────────────────────────────
    if (type == ActivityType.comparar) {
      return [
        _q(ts, 1, '¿Cuál grupo tiene más?', [3, 5], 5, [3,4,5,6], '🍎', '🍊'),
        _q(ts, 2, '¿Cuál grupo tiene más?', [6, 2], 6, [2,4,6,8], '🌟', '🌙'),
        _q(ts, 3, '¿Cuál grupo tiene más?', [4, 7], 7, [4,5,6,7], '🐶', '🐱'),
        _q(ts, 4, '¿Cuál grupo tiene más?', [1, 3], 3, [1,2,3,4], '🍓', '🍇'),
        _q(ts, 5, '¿Cuál grupo tiene más?', [5, 2], 5, [2,3,4,5], '❤️', '💙'),
      ];
    }

    // ── Resta visual ──────────────────────────────────────
    if (type == ActivityType.restaVisual) {
      return [
        _q(ts, 1, '¿Cuánto es 5 − 2?', [5, 2], 3, [2,3,4,5], '🍎', '🍊'),
        _q(ts, 2, '¿Cuánto es 6 − 3?', [6, 3], 3, [2,3,4,5], '🌟', '🌙'),
        _q(ts, 3, '¿Cuánto es 4 − 1?', [4, 1], 3, [1,2,3,4], '🐶', '🐱'),
        _q(ts, 4, '¿Cuánto es 7 − 4?', [7, 4], 3, [2,3,4,5], '🍓', '🍇'),
        _q(ts, 5, '¿Cuánto es 3 − 2?', [3, 2], 1, [1,2,3,4], '❤️', '💙'),
      ];
    }

    // ── Suma visual (default) ─────────────────────────────
    return [
      _q(ts, 1, '¿Cuánto es 2 + 3?', [2, 3], 5, [4,5,6,7], '🌟', '🌙'),
      _q(ts, 2, '¿Cuánto es 1 + 4?', [1, 4], 5, [3,4,5,6], '🍊', '🍊'),
      _q(ts, 3, '¿Cuánto es 3 + 2?', [3, 2], 5, [4,5,6,7], '🐶', '🐱'),
      _q(ts, 4, '¿Cuánto es 2 + 2?', [2, 2], 4, [3,4,5,6], '🍎', '🍎'),
      _q(ts, 5, '¿Cuánto es 1 + 3?', [1, 3], 4, [2,3,4,5], '🍓', '🍇'),
    ];
  }

  QuestionModel _q(int ts, int n, String text, List<dynamic> operands,
      int correct, List<int> choices, String? e1, String? e2) {
    return QuestionModel(
      id: 'offline_${ts}_$n',
      questionText: text,
      activityType: widget.activity.id,
      operands: operands,
      correctAnswer: correct,
      choices: choices,
      hint: 'Observa bien los elementos',
      emoji1: e1,
      emoji2: e2,
      difficulty: 'facil',
    );
  }

  // unused legacy — kept for reference
  List<QuestionModel> _legacyOffline(int ts) {
    return [
      QuestionModel(
        id: 'offline_${ts}_1',
        questionText: '¿Cuántos objetos hay?',
        activityType: widget.activity.id,
        operands: [3],
        correctAnswer: 3,
        choices: [2, 3, 4, 5],
        hint: 'Cuenta los objetos uno por uno',
        emoji1: '🍎',
        emoji2: null,
        difficulty: 'facil',
      ),
      QuestionModel(
        id: 'offline_${ts}_2',
        questionText: '¿Cuánto es 2 + 3?',
        activityType: widget.activity.id,
        operands: [2, 3],
        correctAnswer: 5,
        choices: [4, 5, 6, 7],
        hint: 'Cuenta todos los objetos juntos',
        emoji1: '🌟',
        emoji2: '🌙',
        difficulty: 'facil',
      ),
      QuestionModel(
        id: 'offline_${ts}_3',
        questionText: '¿Cuánto es 1 + 4?',
        activityType: widget.activity.id,
        operands: [1, 4],
        correctAnswer: 5,
        choices: [3, 4, 5, 6],
        hint: 'Usa tus dedos para contar',
        emoji1: '🍊',
        emoji2: '🍊',
        difficulty: 'facil',
      ),
      QuestionModel(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}_4',
        questionText: '¿Cuánto es 3 + 2?',
        activityType: widget.activity.id,
        operands: [3, 2],
        correctAnswer: 5,
        choices: [4, 5, 6, 7],
        hint: 'Cuenta primero un grupo y luego el otro',
        emoji1: '🐶',
        emoji2: '🐱',
        difficulty: 'facil',
      ),
      QuestionModel(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}_5',
        questionText: '¿Cuántos hay en total?',
        activityType: widget.activity.id,
        operands: [4],
        correctAnswer: 4,
        choices: [3, 4, 5, 6],
        hint: 'Toca cada objeto para contarlo',
        emoji1: '⭐',
        emoji2: null,
        difficulty: 'facil',
      ),
    ];
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}