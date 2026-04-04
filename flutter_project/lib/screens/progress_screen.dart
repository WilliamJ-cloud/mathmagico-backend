import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';
import '../services/api_service.dart';
import '../widgets/mascot_widget.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  final Map<String, Map<String, dynamic>> _skillsMeta = {
    'conteo':     {'label': 'Contar objetos',    'emoji': '✋', 'color': AppColors.success},
    'suma':       {'label': 'Suma visual',        'emoji': '🍎', 'color': AppColors.primary},
    'resta':      {'label': 'Resta visual',       'emoji': '➖', 'color': AppColors.secondary},
    'comparar':   {'label': 'Comparar',           'emoji': '📏', 'color': AppColors.accent},
    'secuencias': {'label': 'Secuencias',         'emoji': '🔢', 'color': const Color(0xFF9C27B0)},
    'reconocer':  {'label': 'Reconocer números',  'emoji': '👁️', 'color': const Color(0xFF00BCD4)},
  };

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final user = context.read<UserProvider>().user;
    if (user == null) { setState(() => _isLoading = false); return; }
    final progress = await context.read<ApiService>().getUserProgress(user.id);
    if (progress != null && mounted) {
      context.read<ProgressProvider>().setProgress(ProgressModel.fromJson(progress));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user     = context.watch<UserProvider>().user;
    final progress = context.watch<ProgressProvider>().progress;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStats(user).animate().fadeIn(),
          const SizedBox(height: 18),

          // AI insight
          if (progress?.aiInsight.isNotEmpty == true) ...[
            MascotWidget(
              message: progress!.aiInsight,
              backgroundColor: const Color(0xFFFFF8E1),
            ).animate().slideX(begin: -0.1).fadeIn(),
            const SizedBox(height: 18),
          ],

          // Skills
          _sectionTitle('Mis habilidades', loading: _isLoading),
          const SizedBox(height: 10),
          _buildSkills(user),

          const SizedBox(height: 22),

          // Streak + weekly strip
          _buildStreakCard(user).animate().slideY(begin: 0.15).fadeIn(delay: 100.ms),

          const SizedBox(height: 18),

          // Monthly calendar
          _buildMonthlyCalendar(user).animate().slideY(begin: 0.15).fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  // ── Quick stats ────────────────────────────────────────

  Widget _buildQuickStats(UserModel? user) {
    return Row(children: [
      _statCard('⭐', '${user?.totalPoints ?? 0}', 'Puntos', AppColors.primary),
      const SizedBox(width: 10),
      _statCard('🏆', 'Nivel ${user?.calculatedLevel ?? 1}', 'Nivel', AppColors.accent),
      const SizedBox(width: 10),
      _statCard('🔥', '${user?.currentStreak ?? 0}', 'Días seguidos', AppColors.secondary),
    ]);
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.nunito(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color),
              textAlign: TextAlign.center),
          Text(label,
              style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────

  Widget _sectionTitle(String text, {bool loading = false}) {
    return Row(children: [
      Container(width: 5, height: 22,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary)),
    ]);
  }

  // ── Skills ─────────────────────────────────────────────

  Widget _buildSkills(UserModel? user) {
    final skills = user?.skillLevels ?? {
      'conteo': 0, 'suma': 0, 'resta': 0,
      'comparar': 0, 'secuencias': 0, 'reconocer': 0,
    };
    return Column(
      children: skills.entries.toList().asMap().entries.map((entry) {
        final i    = entry.key;
        final e    = entry.value;
        final meta = _skillsMeta[e.key] ??
            {'label': e.key, 'emoji': '📚', 'color': AppColors.primary};
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _skillBar(
            emoji: meta['emoji'] as String,
            label: meta['label'] as String,
            pct:   (e.value / 100.0).clamp(0.0, 1.0),
            color: meta['color'] as Color,
          ).animate(delay: Duration(milliseconds: 70 * i)).slideX(begin: -0.1).fadeIn(),
        );
      }).toList(),
    );
  }

  Widget _skillBar({required String emoji, required String label,
      required double pct, required Color color}) {
    String badge;
    if (pct >= 0.8) badge = 'Excelente 🌟';
    else if (pct >= 0.6) badge = 'Bien 👍';
    else if (pct >= 0.3) badge = 'Practicando 💪';
    else badge = 'Empezando 🌱';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          Text(badge,
              style: GoogleFonts.nunito(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('${(pct * 100).toInt()}%',
              style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ]),
    );
  }

  // ── Streak card (this week) ────────────────────────────

  Widget _buildStreakCard(UserModel? user) {
    final streak = user?.currentStreak ?? 0;
    final today  = DateTime.now();

    // Build Mon–Sun of the current week
    final weekday = today.weekday; // 1=Mon … 7=Sun
    final monday  = today.subtract(Duration(days: weekday - 1));

    const dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withOpacity(0.07),
          AppColors.primaryLight.withOpacity(0.07),
        ]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Streak badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: streak > 0
                  ? const Color(0xFFFF6B35)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text('$streak día${streak != 1 ? 's' : ''}',
                  style: GoogleFonts.nunito(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              streak == 0
                  ? '¡Empieza tu racha hoy!'
                  : streak < 3
                      ? '¡Buen comienzo, sigue así!'
                      : streak < 7
                          ? '¡Excelente racha! 💪'
                          : '¡Semana perfecta! 🏆',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Day circles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day     = monday.add(Duration(days: i));
            final isFuture = day.isAfter(today);
            final practiced = user?.practicedOn(day) ?? false;
            final isToday  = _sameDay(day, today);

            Color bg;
            Color textColor;
            if (practiced) {
              bg = AppColors.primary;
              textColor = Colors.white;
            } else if (isToday) {
              bg = AppColors.primary.withOpacity(0.15);
              textColor = AppColors.primary;
            } else if (isFuture) {
              bg = Colors.grey.shade100;
              textColor = Colors.grey.shade300;
            } else {
              bg = Colors.grey.shade200;
              textColor = AppColors.textHint;
            }

            return Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: isToday && !practiced
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    practiced ? '✓' : dayLabels[i],
                    style: GoogleFonts.nunito(
                        fontSize: practiced ? 16 : 13,
                        fontWeight: FontWeight.w800,
                        color: textColor),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(dayLabels[i],
                  style: GoogleFonts.nunito(
                      fontSize: 10, color: AppColors.textHint)),
            ]);
          }),
        ),
      ]),
    );
  }

  // ── Monthly calendar with navigation ─────────────────

  Widget _buildMonthlyCalendar(UserModel? user) {
    final today = DateTime.now();
    final isCurrentMonth = _calendarMonth.year == today.year &&
        _calendarMonth.month == today.month;
    final canGoNext = !isCurrentMonth;

    // Count active days in the displayed month
    final daysActive = user?.activityDates.where((s) {
          final d = DateTime.parse(s);
          return d.year == _calendarMonth.year && d.month == _calendarMonth.month;
        }).length ?? 0;

    // Build cells: first day of month → pad to Monday → last day of month → pad to Sunday
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay  = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final gridStart = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final gridEnd   = lastDay.add(Duration(days: 7 - lastDay.weekday));

    final cells = <DateTime>[];
    var cursor = gridStart;
    while (!cursor.isAfter(gridEnd)) {
      cells.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }

    final monthLabel =
        '${_monthNames[_calendarMonth.month]} de ${_calendarMonth.year}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Month navigation header ──────────────────────
        Row(children: [
          const Text('📅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Calendario de racha',
                style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$daysActive días activos',
                style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
        const SizedBox(height: 12),

        // Month name + prev/next arrows
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _navArrow(Icons.chevron_left, () {
            setState(() {
              _calendarMonth = DateTime(
                  _calendarMonth.year, _calendarMonth.month - 1);
            });
          }),
          Text(
            monthLabel,
            style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          _navArrow(Icons.chevron_right, canGoNext
              ? () {
                  setState(() {
                    _calendarMonth = DateTime(
                        _calendarMonth.year, _calendarMonth.month + 1);
                  });
                }
              : null),
        ]),
        const SizedBox(height: 10),

        // Day-of-week header
        Row(
          children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
              .map((d) => Expanded(
                    child: Text(d,
                        style: GoogleFonts.nunito(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.textHint),
                        textAlign: TextAlign.center),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),

        // Calendar grid — strict 7-column rows
        ...List.generate((cells.length / 7).ceil(), (rowIdx) {
          final rowCells = cells.skip(rowIdx * 7).take(7).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: rowCells.map((day) {
                final inMonth   = day.month == _calendarMonth.month;
                final isFuture  = day.isAfter(today);
                final isToday   = _sameDay(day, today);
                final practiced = inMonth && !isFuture &&
                    (user?.practicedOn(day) ?? false);

                Color bg;
                Color textColor;
                double opacity = inMonth ? 1.0 : 0.25;

                if (practiced) {
                  bg = AppColors.primary;
                  textColor = Colors.white;
                } else if (isToday) {
                  bg = AppColors.primary.withOpacity(0.15);
                  textColor = AppColors.primary;
                } else if (isFuture) {
                  bg = Colors.transparent;
                  textColor = Colors.grey.shade400;
                  opacity = inMonth ? 0.4 : 0.0;
                } else {
                  bg = Colors.grey.shade100;
                  textColor = inMonth ? AppColors.textHint : Colors.grey.shade400;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 34,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !practiced
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: practiced || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),

        const SizedBox(height: 14),
        // Legend
        Row(children: [
          _legendDot(AppColors.primary), const SizedBox(width: 4),
          Text('Día practicado',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          _legendDot(Colors.grey.shade100, border: true), const SizedBox(width: 4),
          Text('Sin actividad',
              style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _navArrow(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 20,
            color: onTap != null ? AppColors.primary : Colors.grey.shade400),
      ),
    );
  }

  Widget _legendDot(Color color, {bool border = false}) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: border ? Border.all(color: Colors.grey.shade300) : null,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
