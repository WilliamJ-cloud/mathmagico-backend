import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const List<Map<String, dynamic>> _allAchievements = [
    {
      'id': 'primer_suma',
      'title': 'Primera suma',
      'description': 'Completa tu primera suma',
      'emoji': '🍎',
      'gradient': [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
    },
    {
      'id': 'contador_experto',
      'title': 'Contador experto',
      'description': 'Cuenta perfecto sin errores',
      'emoji': '✋',
      'gradient': [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    },
    {
      'id': 'maestro_comparacion',
      'title': 'Maestro comparador',
      'description': 'Compara sin equivocarte',
      'emoji': '📏',
      'gradient': [Color(0xFFC62828), Color(0xFFEF5350)],
    },
    {
      'id': 'orden_perfecto',
      'title': 'Orden perfecto',
      'description': 'Ordena secuencias sin errores',
      'emoji': '🔢',
      'gradient': [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    },
    {
      'id': 'numero_maestro',
      'title': 'Maestro de números',
      'description': 'Reconoce todos los números',
      'emoji': '👁️',
      'gradient': [Color(0xFF00838F), Color(0xFF26C6DA)],
    },
    {
      'id': 'semana_perfecta',
      'title': 'Semana perfecta',
      'description': 'Practica 7 días seguidos',
      'emoji': '🔥',
      'gradient': [Color(0xFFE65100), Color(0xFFFF7043)],
    },
    {
      'id': 'cien_puntos',
      'title': '¡100 puntos!',
      'description': 'Acumula 100 puntos',
      'emoji': '⭐',
      'gradient': [Color(0xFFF57F17), Color(0xFFFFCA28)],
    },
    {
      'id': 'sin_pistas',
      'title': 'Sin ayuda',
      'description': 'Completa una actividad solo',
      'emoji': '💪',
      'gradient': [Color(0xFF1565C0), Color(0xFF42A5F5)],
    },
    {
      'id': 'velocista',
      'title': 'Velocista',
      'description': 'Termina en menos de 2 min',
      'emoji': '⚡',
      'gradient': [Color(0xFF00695C), Color(0xFF26A69A)],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final earned = user?.achievements ?? [];

    final earnedList =
        _allAchievements.where((a) => earned.contains(a['id'])).toList();
    final lockedList =
        _allAchievements.where((a) => !earned.contains(a['id'])).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          _buildHeader(earned.length).animate().fadeIn().slideY(begin: -0.1),

          const SizedBox(height: 20),

          // ── Logros obtenidos ─────────────────────────────
          if (earnedList.isNotEmpty) ...[
            _sectionLabel('🏆 Tus logros (${earnedList.length})'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.82,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: earnedList.length,
              itemBuilder: (_, i) => _buildCard(earnedList[i],
                      earned: true, delay: i * 80)
                  .animate(delay: Duration(milliseconds: i * 80))
                  .scale(begin: const Offset(0.7, 0.7),
                      curve: Curves.elasticOut)
                  .fadeIn(),
            ),
            const SizedBox(height: 24),
          ],

          // ── Por desbloquear ─────────────────────────────
          _sectionLabel('🔒 Por desbloquear (${lockedList.length})'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.82,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: lockedList.length,
            itemBuilder: (_, i) => _buildCard(lockedList[i],
                    earned: false, delay: i * 60)
                .animate(delay: Duration(milliseconds: 100 + i * 60))
                .fadeIn()
                .slideY(begin: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    final total = _allAchievements.length;
    final pct = count / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background circles
          Positioned(
            top: -20,
            right: -10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            left: 80,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 44)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mis logros',
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$count de $total desbloqueados',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFFD93D)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                count == 0
                    ? '¡Completa actividades para ganar logros!'
                    : count == total
                        ? '¡Eres un campeón! 🎉'
                        : '¡Sigue así, vas muy bien! 💪',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> achievement, {
    required bool earned,
    int delay = 0,
  }) {
    final gradientColors = achievement['gradient'] as List<Color>;
    final emoji = achievement['emoji'] as String;
    final title = achievement['title'] as String;
    final description = achievement['description'] as String;

    if (earned) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '¡Obtenido!',
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Locked card — shows color hint with overlay
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: gradientColors[0].withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🔒', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: GoogleFonts.nunito(
                fontSize: 9,
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
