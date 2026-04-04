import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../models/progress_model.dart';

class ParentReportScreen extends StatelessWidget {
  const ParentReportScreen({super.key});

  static const Map<String, Map<String, dynamic>> _skillMeta = {
    'conteo':     {'label': 'Contar objetos',    'emoji': '✋', 'color': Color(0xFF4CAF50)},
    'suma':       {'label': 'Suma visual',        'emoji': '🍎', 'color': Color(0xFF6C63FF)},
    'resta':      {'label': 'Resta visual',       'emoji': '➖', 'color': Color(0xFFFF6B6B)},
    'comparar':   {'label': 'Comparar',           'emoji': '📏', 'color': Color(0xFFFF9800)},
    'secuencias': {'label': 'Secuencias',         'emoji': '🔢', 'color': Color(0xFF9C27B0)},
    'reconocer':  {'label': 'Reconocer números',  'emoji': '👁️', 'color': Color(0xFF00BCD4)},
  };

  @override
  Widget build(BuildContext context) {
    final user    = context.watch<UserProvider>().user;
    final progress = context.watch<ProgressProvider>().progress;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      body: CustomScrollView(
        slivers: [
          // ── AppBar con gradiente ──────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF1A237E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                tooltip: 'Compartir por WhatsApp',
                onPressed: () => _shareWhatsApp(context, user, progress),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              user?.avatarEmoji ?? '🦁',
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Reporte de progreso',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user?.name ?? 'Estudiante',
                                style: GoogleFonts.nunito(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${user?.age ?? 6} años  •  Nivel ${user?.calculatedLevel ?? 1}',
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Estadísticas rápidas
                _buildStatsRow(user, progress)
                    .animate().fadeIn(duration: 500.ms).slideY(begin: 0.15),

                const SizedBox(height: 20),

                // Mensaje para padres
                _buildParentMessage(user)
                    .animate().fadeIn(delay: 100.ms, duration: 500.ms),

                const SizedBox(height: 20),

                // Progreso por habilidad
                _buildSkillsCard(user)
                    .animate().fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideY(begin: 0.1),

                const SizedBox(height: 20),

                // Recomendación pedagógica
                _buildRecommendation(user)
                    .animate().fadeIn(delay: 300.ms, duration: 500.ms),

                const SizedBox(height: 20),

                // Logros
                _buildAchievements(user)
                    .animate().fadeIn(delay: 400.ms, duration: 500.ms),

                const SizedBox(height: 24),

                // Botón compartir WhatsApp
                _buildShareButton(context, user, progress)
                    .animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: 12),

                // Nota al pie
                Center(
                  child: Text(
                    'Generado por MathMágico • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────
  Widget _buildStatsRow(UserModel? user, ProgressModel? progress) {
    final level  = user?.calculatedLevel ?? 1;
    final points = user?.totalPoints ?? 0;
    final streak = progress?.weeklyStreak ?? 0;
    final achievements = user?.achievements.length ?? 0;

    return Row(
      children: [
        _statCard('⭐', '$points', 'Puntos', const Color(0xFF6C63FF)),
        const SizedBox(width: 10),
        _statCard('🏆', 'Nivel $level', 'Nivel', const Color(0xFFFF9800)),
        const SizedBox(width: 10),
        _statCard('🔥', '$streak días', 'Racha', const Color(0xFFFF5722)),
        const SizedBox(width: 10),
        _statCard('🎖️', '$achievements', 'Logros', const Color(0xFF4CAF50)),
      ],
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mensaje para padres ───────────────────────────────────
  Widget _buildParentMessage(UserModel? user) {
    final name   = user?.name ?? 'el estudiante';
    final level  = user?.calculatedLevel ?? 1;
    final points = user?.totalPoints ?? 0;

    String msg;
    if (points == 0) {
      msg = '$name acaba de comenzar su aventura en MathMágico. '
          'Anímale a completar sus primeras actividades. '
          '¡Cada sesión es un gran paso!';
    } else if (level >= 4) {
      msg = '¡$name está teniendo un desempeño excelente! '
          'Ha alcanzado el nivel $level con $points puntos. '
          'Su constancia y esfuerzo son admirables. ¡Sigan así!';
    } else {
      msg = '$name está avanzando muy bien con $points puntos '
          'en nivel $level. Practicar unos minutos cada día '
          'marcará una gran diferencia. ¡Lo está haciendo genial!';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD93D).withOpacity(0.6), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🦉', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensaje para papá y mamá',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF795548),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: const Color(0xFF5D4037),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Habilidades ───────────────────────────────────────────
  Widget _buildSkillsCard(UserModel? user) {
    final skills = user?.skillLevels ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                'Progreso por habilidad',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (skills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sin actividades completadas aún',
                  style: GoogleFonts.nunito(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._skillMeta.entries.map((entry) {
              final pct = ((skills[entry.key] ?? 0) / 100.0).clamp(0.0, 1.0);
              final color = entry.value['color'] as Color;
              final label = _skillLabel(pct);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(entry.value['emoji'] as String,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value['label'] as String,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${(pct * 100).toInt()}%',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 9,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _skillLabel(double pct) {
    if (pct >= 0.8) return 'Excelente';
    if (pct >= 0.6) return 'Bien';
    if (pct >= 0.3) return 'Practicando';
    return 'Iniciando';
  }

  // ── Recomendación pedagógica ──────────────────────────────
  Widget _buildRecommendation(UserModel? user) {
    final skills = user?.skillLevels ?? {};
    String weakSkill = '';
    int minVal = 101;

    skills.forEach((key, val) {
      if (val < minVal) {
        minVal = val;
        weakSkill = key;
      }
    });

    final meta = _skillMeta[weakSkill];
    final recommendation = skills.isEmpty
        ? 'Se recomienda comenzar con la actividad de Contar objetos. '
            'Es la base de todas las habilidades matemáticas.'
        : minVal < 40
            ? 'Se recomienda dedicar tiempo extra a "${meta?['label'] ?? weakSkill}". '
                'Practicar con objetos físicos en casa complementa muy bien las sesiones digitales.'
            : minVal < 70
                ? 'Buen avance general. Reforzar "${meta?['label'] ?? weakSkill}" '
                    'ayudará a consolidar todas las demás habilidades.'
                : '¡Excelente desempeño en todas las áreas! '
                    'Mantener la práctica diaria de 10-15 minutos asegura el progreso continuo.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Recomendación pedagógica',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Practicar 10-15 min diarios es más efectivo que sesiones largas esporádicas.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: const Color(0xFF4F46E5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Logros ────────────────────────────────────────────────
  Widget _buildAchievements(UserModel? user) {
    final earned = user?.achievements ?? [];
    if (earned.isEmpty) return const SizedBox.shrink();

    const allAchievements = {
      'primer_suma':        {'emoji': '🍎', 'title': 'Primera suma'},
      'contador_experto':   {'emoji': '✋', 'title': 'Contador experto'},
      'maestro_comparacion':{'emoji': '📏', 'title': 'Maestro comparador'},
      'orden_perfecto':     {'emoji': '🔢', 'title': 'Orden perfecto'},
      'numero_maestro':     {'emoji': '👁️', 'title': 'Maestro números'},
      'semana_perfecta':    {'emoji': '🔥', 'title': 'Semana perfecta'},
      'cien_puntos':        {'emoji': '⭐', 'title': '100 puntos'},
      'sin_pistas':         {'emoji': '💪', 'title': 'Sin ayuda'},
      'velocista':          {'emoji': '⚡', 'title': 'Velocista'},
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Logros obtenidos (${earned.length})',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A237E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: earned.map((id) {
              final a = allAchievements[id];
              if (a == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFFD93D).withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(a['emoji']!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      a['title']!,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF795548),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Botón WhatsApp ────────────────────────────────────────
  Widget _buildShareButton(BuildContext context, UserModel? user,
      ProgressModel? progress) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () => _shareWhatsApp(context, user, progress),
        icon: const Icon(Icons.send_rounded, size: 20),
        label: Text(
          'Compartir reporte por WhatsApp',
          style: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Compartir por WhatsApp ────────────────────────────────
  Future<void> _shareWhatsApp(BuildContext context, UserModel? user,
      ProgressModel? progress) async {
    final name   = user?.name ?? 'el estudiante';
    final level  = user?.calculatedLevel ?? 1;
    final points = user?.totalPoints ?? 0;
    final skills = user?.skillLevels ?? {};

    final skillLines = _skillMeta.entries.map((e) {
      final pct = skills[e.key] ?? 0;
      final bar = _progressBar(pct);
      return '  ${e.value['emoji']} ${e.value['label']}: $bar $pct%';
    }).join('\n');

    final rawMsg =
      '📚 *Reporte de progreso — MathMágico*\n\n'
      '👤 Estudiante: *$name*\n'
      '🏆 Nivel alcanzado: *Nivel $level*\n'
      '⭐ Puntos totales: *$points pts*\n'
      '🎖️ Logros: *${user?.achievements.length ?? 0}*\n\n'
      '📊 *Progreso por habilidad:*\n'
      '$skillLines\n\n'
      '🦉 Reporte generado por MathMágico\n'
      '📅 ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

    final encoded = Uri.encodeComponent(rawMsg);

    // Intenta URI nativa de WhatsApp primero (más confiable en Android)
    final waUri = Uri.parse('whatsapp://send?text=$encoded');
    final waWeb = Uri.parse('https://wa.me/?text=$encoded');

    bool opened = false;
    if (await canLaunchUrl(waUri)) {
      opened = await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
    if (!opened && await canLaunchUrl(waWeb)) {
      opened = await launchUrl(waWeb, mode: LaunchMode.externalApplication);
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WhatsApp no encontrado. Instálalo e intenta de nuevo.',
            style: GoogleFonts.nunito(),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _progressBar(int pct) {
    final filled = (pct / 10).round().clamp(0, 10);
    return '[${'█' * filled}${'░' * (10 - filled)}]';
  }
}
