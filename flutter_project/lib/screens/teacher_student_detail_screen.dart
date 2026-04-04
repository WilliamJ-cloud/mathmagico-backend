import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_theme.dart';
import '../config/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherStudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  final String teacherId;
  final String token;

  const TeacherStudentDetailScreen({
    super.key,
    required this.student,
    required this.teacherId,
    required this.token,
  });

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState
    extends State<TeacherStudentDetailScreen> {
  Map<String, dynamic> _progress = {};
  bool _isLoading = true;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  final Map<String, Map<String, dynamic>> _skillsMeta = {
    'suma_visual': {'label': 'Suma visual', 'emoji': '🍎'},
    'resta_visual': {'label': 'Resta visual', 'emoji': '➖'},
    'conteo': {'label': 'Conteo táctil', 'emoji': '✋'},
    'comparar': {'label': 'Comparar', 'emoji': '📏'},
    'secuencias': {'label': 'Secuencias', 'emoji': '🔢'},
    'reconocer_numeros': {'label': 'Reconocer números', 'emoji': '👁️'},
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _loadProgress();
  }

  @override
  void reassemble() {
    super.reassemble();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/teachers/${widget.teacherId}'
          '/students/${widget.student['id']}/progress',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        setState(() => _progress = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error cargando progreso: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendWhatsApp() async {
    final student = _progress['student'] ?? widget.student;
    final phone = (student['parent_phone'] ?? '')
        .toString()
        .replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay numero de celular registrado para el tutor.',
              style: GoogleFonts.nunito()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final name = student['name'] ?? 'el estudiante';
    final level = student['level'] ?? 1;
    final points = student['total_points'] ?? 0;

    // Calcular habilidad más débil
    final skills = Map<String, dynamic>.from(_progress['skills'] ?? {});
    String weakInfo = '';
    if (skills.isNotEmpty) {
      String weakKey = skills.keys.first;
      double minAcc = 101;
      skills.forEach((k, v) {
        final acc = (v['accuracy'] as num?)?.toDouble() ?? 0.0;
        if (acc < minAcc) {
          minAcc = acc;
          weakKey = k;
        }
      });
      final nombres = {
        'suma_visual': 'suma visual',
        'resta_visual': 'resta visual',
        'conteo': 'conteo',
        'comparar': 'comparar cantidades',
        'secuencias': 'secuencias',
        'reconocer_numeros': 'reconocer numeros',
      };
      weakInfo = '\n- Necesita refuerzo en: ${nombres[weakKey] ?? weakKey} '
          '(${minAcc.toStringAsFixed(0)}% de precision)';
    }

    final mensaje = Uri.encodeComponent(
      'Hola, soy el/la profesor/a de ${name}.\n\n'
      'Le comparto el reporte de progreso de MathMágico:\n\n'
      '📚 Estudiante: $name\n'
      '🏆 Nivel alcanzado: $level\n'
      '⭐ Puntos totales: $points'
      '$weakInfo\n\n'
      'Para ver el reporte completo en PDF, el profesor puede '
      'generarlo desde el portal MathMágico.\n\n'
      '¡Gracias por apoyar el aprendizaje de $name!',
    );

    // Número con código de país Bolivia (+591)
    final fullPhone = phone.startsWith('591') ? phone : '591$phone';
    final url = Uri.parse('https://wa.me/$fullPhone?text=$mensaje');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No se pudo abrir WhatsApp.', style: GoogleFonts.nunito()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editStudent() async {
    final student = _progress['student'] ?? widget.student;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditStudentDialog(student: student),
    );
    if (result == null) return;

    try {
      final response = await http.put(
        Uri.parse(
          '${AppConstants.baseUrl}/teachers/${widget.teacherId}'
          '/students/${student['id']}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(result),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Datos actualizados correctamente',
                style: GoogleFonts.nunito()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProgress();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e',
                style: GoogleFonts.nunito()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPdf() async {
    final student = _progress['student'] ?? widget.student;
    final url = '${AppConstants.baseUrl}/teachers/${widget.teacherId}'
        '/students/${student['id']}/report-pdf';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _progress['student'] ?? widget.student;
    final skills = Map<String, dynamic>.from(_progress['skills'] ?? {});
    final totalSessions = _progress['total_sessions'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: Text(
          student['name'] ?? 'Estudiante',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Editar datos del tutor',
            onPressed: _editStudent,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Card perfil estudiante
                  _buildProfileCard(student, totalSessions),
                  const SizedBox(height: 16),

                  // Habilidades
                  _buildSkillsCard(skills),
                  const SizedBox(height: 16),

                  // Calendario de asistencia
                  _buildCalendarCard(),
                  const SizedBox(height: 16),

                  // Sesiones recientes
                  _buildRecentSessions(),
                  const SizedBox(height: 16),

                  // Datos del tutor
                  _buildParentCard(student),
                  const SizedBox(height: 16),

                  // Recomendación pedagógica
                  _buildRecommendation(skills),
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.picture_as_pdf,
                              color: Colors.white),
                          label: Text('Descargar PDF',
                              style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendWhatsApp,
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: Text('WhatsApp',
                              style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ).animate().slideY(begin: 0.2).fadeIn(delay: 400.ms),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> student, int totalSessions) {
    final level = student['level'] ?? 1;
    final points = student['total_points'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                student['avatar_emoji'] ?? '🦁',
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] ?? '',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${student['age']} años • ${student['grade'] ?? ''}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip('⭐ $points pts'),
                    const SizedBox(width: 8),
                    _buildChip('🏆 Nivel $level'),
                    const SizedBox(width: 8),
                    _buildChip('📚 $totalSessions sesiones'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSkillsCard(Map<String, dynamic> skills) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Progreso por habilidad',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 14),
          if (skills.isEmpty)
            Center(
              child: Text(
                'Sin actividades completadas aún',
                style: GoogleFonts.nunito(color: AppColors.textSecondary),
              ),
            )
          else
            ...skills.entries.map((entry) {
              final meta =
                  _skillsMeta[entry.key] ?? {'label': entry.key, 'emoji': '📚'};
              final accuracy =
                  (entry.value['accuracy'] as num?)?.toDouble() ?? 0.0;
              final sessions = entry.value['sessions'] ?? 0;

              Color barColor = AppColors.error;
              if (accuracy >= 70)
                barColor = AppColors.success;
              else if (accuracy >= 50) barColor = AppColors.warning;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(meta['emoji'] as String,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            meta['label'] as String,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '$sessions sesiones',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${accuracy.toStringAsFixed(0)}%',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: accuracy / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(barColor),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().slideY(begin: 0.1).fadeIn(delay: 100.ms);
  }

  // ── Calendar card ─────────────────────────────────────

  Widget _buildCalendarCard() {
    final today = DateTime.now();
    const accent = Color(0xFF1A237E);

    final rawDates = List<String>.from(_progress['activity_dates'] ?? []);
    final activeDates = rawDates.toSet();

    // Streak
    int streak = 0;
    if (activeDates.isNotEmpty) {
      final sorted = activeDates.map(DateTime.parse).toList()
        ..sort((a, b) => b.compareTo(a));
      final todayStr = _fmt(today);
      final yestStr  = _fmt(today.subtract(const Duration(days: 1)));
      if (_fmt(sorted.first) == todayStr || _fmt(sorted.first) == yestStr) {
        streak = 1;
        for (int i = 1; i < sorted.length; i++) {
          if (_fmt(sorted[i]) == _fmt(sorted[i-1].subtract(const Duration(days: 1)))) {
            streak++;
          } else break;
        }
      }
    }

    // Days active in displayed month
    final daysActive = activeDates.where((s) {
      final d = DateTime.parse(s);
      return d.year == _calendarMonth.year && d.month == _calendarMonth.month;
    }).length;

    final isCurrentMonth = _calendarMonth.year == today.year &&
        _calendarMonth.month == today.month;

    // Full month grid aligned to Monday
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay  = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final gridEnd   = lastDay.add(Duration(days: 7 - lastDay.weekday));

    final cells = <DateTime>[];
    var cur = gridStart;
    while (!cur.isAfter(gridEnd)) {
      cells.add(cur);
      cur = cur.add(const Duration(days: 1));
    }

    final monthLabel =
        '${_monthNames[_calendarMonth.month]} de ${_calendarMonth.year}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Title + badges
        Row(children: [
          const Text('📅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Calendario de racha',
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _calBadge('🔥 $streak días seguidos',
              streak > 0 ? const Color(0xFFFF6B35) : Colors.grey),
          const SizedBox(width: 8),
          _calBadge('✅ $daysActive días activos', accent),
        ]),
        const SizedBox(height: 14),

        // Month navigation
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _navArrow(Icons.chevron_left, accent, () {
            setState(() {
              _calendarMonth =
                  DateTime(_calendarMonth.year, _calendarMonth.month - 1);
            });
          }),
          Text(monthLabel,
              style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w800, color: accent)),
          _navArrow(Icons.chevron_right, accent, isCurrentMonth
              ? null
              : () {
                  setState(() {
                    _calendarMonth =
                        DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                  });
                }),
        ]),
        const SizedBox(height: 10),

        // Week header
        Row(
          children: ['L','M','X','J','V','S','D'].map((d) => Expanded(
            child: Text(d,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.grey)),
          )).toList(),
        ),
        const SizedBox(height: 6),

        // Calendar rows of 7
        ...List.generate((cells.length / 7).ceil(), (rowIdx) {
          final rowCells = cells.skip(rowIdx * 7).take(7).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: rowCells.map((day) {
                final inMonth  = day.month == _calendarMonth.month;
                final isFuture = day.isAfter(today);
                final isToday  = _sameDay(day, today);
                final practiced = inMonth && !isFuture &&
                    activeDates.contains(_fmt(day));

                Color bg;
                Color fg;
                double op = inMonth ? 1.0 : 0.25;

                if (practiced) {
                  bg = accent; fg = Colors.white;
                } else if (isToday) {
                  bg = accent.withOpacity(0.12); fg = accent;
                } else if (isFuture) {
                  bg = Colors.transparent;
                  fg = Colors.grey.shade400;
                  op = inMonth ? 0.4 : 0.0;
                } else {
                  bg = Colors.grey.shade100;
                  fg = inMonth ? Colors.grey.shade500 : Colors.grey.shade400;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: op,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 34,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !practiced
                              ? Border.all(color: accent, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text('${day.day}',
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: practiced || isToday
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: fg)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),

        const SizedBox(height: 12),
        Row(children: [
          _legendDot(accent),
          const SizedBox(width: 4),
          Text('Día practicado',
              style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 14),
          _legendDot(Colors.grey.shade100, border: true),
          const SizedBox(width: 4),
          Text('Sin actividad',
              style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
        ]),
      ]),
    ).animate().slideY(begin: 0.1).fadeIn(delay: 200.ms);
  }

  Widget _navArrow(IconData icon, Color accent, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? accent.withOpacity(0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 20,
            color: onTap != null ? accent : Colors.grey.shade400),
      ),
    );
  }

  Widget _calBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _legendDot(Color color, {bool border = false}) {
    return Container(
      width: 13, height: 13,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: border ? Border.all(color: Colors.grey.shade300) : null,
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildRecentSessions() {
    final sessions =
        List<Map<String, dynamic>>.from(_progress['recent_sessions'] ?? []);

    final activityNames = {
      'suma_visual': '🍎 Suma visual',
      'resta_visual': '➖ Resta visual',
      'conteo': '✋ Conteo',
      'comparar': '📏 Comparar',
      'secuencias': '🔢 Secuencias',
      'reconocer_numeros': '👁️ Reconocer números',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🕐 Sesiones recientes',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Center(
              child: Text(
                'Sin sesiones recientes',
                style: GoogleFonts.nunito(color: AppColors.textSecondary),
              ),
            )
          else
            ...sessions.take(5).map((s) {
              final accuracy = (s['accuracy'] as num?)?.toDouble() ?? 0.0;
              final actName =
                  activityNames[s['activity_type']] ?? s['activity_type'];
              Color accColor = AppColors.error;
              if (accuracy >= 0.7)
                accColor = AppColors.success;
              else if (accuracy >= 0.5) accColor = AppColors.warning;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        actName,
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${s['correct_answers']}/${s['total_questions']} correctas',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(accuracy * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    ).animate().slideY(begin: 0.1).fadeIn(delay: 200.ms);
  }

  Widget _buildParentCard(Map<String, dynamic> student) {
    final parentName = student['parent_name'] ?? '';
    final parentPhone = student['parent_phone'] ?? '';
    final hasParentData = parentName.isNotEmpty || parentPhone.isNotEmpty;
    final studentId = student['id'] ?? '';

    return Column(children: [
      // ── Código del estudiante ──────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.badge_outlined, color: Color(0xFF7B1FA2), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Código del estudiante',
                  style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF7B1FA2))),
              Text(studentId,
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: Colors.grey.shade700)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: const Color(0xFF7B1FA2),
            tooltip: 'Copiar código',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: studentId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Código copiado — compártelo con el estudiante',
                      style: GoogleFonts.nunito()),
                  backgroundColor: const Color(0xFF7B1FA2),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ]),
      ),

      const SizedBox(height: 12),

    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasParentData
              ? const Color(0xFF25D366).withOpacity(0.4)
              : Colors.orange.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '👨‍👩‍👦 Datos del tutor',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A237E),
                ),
              ),
              const Spacer(),
              if (!hasParentData)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'Pendiente',
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasParentData)
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No hay datos del tutor. Toca ✏️ para agregarlos.',
                    style: GoogleFonts.nunito(
                        fontSize: 13, color: Colors.orange.shade700),
                  ),
                ),
              ],
            )
          else ...[
            if (parentName.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 18, color: Color(0xFF1A237E)),
                  const SizedBox(width: 8),
                  Text(
                    parentName,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            if (parentName.isNotEmpty && parentPhone.isNotEmpty)
              const SizedBox(height: 6),
            if (parentPhone.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 18, color: Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Text(
                    parentPhone,
                    style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
          ],
        ],
      ),
    ).animate().slideY(begin: 0.1).fadeIn(delay: 150.ms),
    ]); // end Column
  }

  Widget _buildRecommendation(Map<String, dynamic> skills) {
    String weakSkill = '';
    double minAcc = 101;

    skills.forEach((key, value) {
      final acc = (value['accuracy'] as num?)?.toDouble() ?? 0.0;
      if (acc < minAcc) {
        minAcc = acc;
        weakSkill = key;
      }
    });

    final skillNames = {
      'suma_visual': 'suma visual',
      'resta_visual': 'resta visual',
      'conteo': 'conteo',
      'comparar': 'comparar cantidades',
      'secuencias': 'ordenar secuencias',
      'reconocer_numeros': 'reconocer números',
    };

    String recommendation = skills.isEmpty
        ? 'El estudiante aún no ha realizado actividades. Se recomienda comenzar con la actividad de conteo táctil.'
        : minAcc < 60
            ? 'Se recomienda reforzar la actividad de ${skillNames[weakSkill] ?? weakSkill} con precisión del ${minAcc.toStringAsFixed(0)}%. Usar objetos físicos como apoyo concreto.'
            : '¡Buen desempeño general! Continuar practicando para mantener el progreso.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.accent.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🦉', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recomendación pedagógica',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1).fadeIn(delay: 300.ms);
  }
}

// ── Diálogo para editar datos del estudiante/tutor ────────
class _EditStudentDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  const _EditStudentDialog({required this.student});

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _gradeCtrl;
  late final TextEditingController _parentNameCtrl;
  late final TextEditingController _parentPhoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.student['name']?.toString() ?? '');
    _gradeCtrl = TextEditingController(
        text: widget.student['grade']?.toString() ?? '');
    _parentNameCtrl = TextEditingController(
        text: widget.student['parent_name']?.toString() ?? '');
    _parentPhoneCtrl = TextEditingController(
        text: widget.student['parent_phone']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gradeCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Editar datos del estudiante',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_nameCtrl, 'Nombre del estudiante', Icons.person_outline),
            const SizedBox(height: 10),
            _field(_gradeCtrl, 'Grado (ej: 2do primaria)', Icons.school_outlined),
            const SizedBox(height: 16),

            // Separador tutor
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.family_restroom,
                    size: 18, color: Color(0xFF1A237E)),
                const SizedBox(width: 6),
                Text(
                  'Datos del padre / madre / tutor',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A237E),
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),

            _field(_parentNameCtrl, 'Nombre completo del tutor',
                Icons.person_outline),
            const SizedBox(height: 10),
            _field(
              _parentPhoneCtrl,
              'Número de celular (WhatsApp)',
              Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': _nameCtrl.text.trim(),
              'grade': _gradeCtrl.text.trim(),
              'parent_name': _parentNameCtrl.text.trim(),
              'parent_phone': _parentPhoneCtrl.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Guardar',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.nunito(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF1A237E)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1A237E), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
