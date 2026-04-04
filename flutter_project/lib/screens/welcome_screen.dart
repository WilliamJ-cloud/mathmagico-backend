import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_screen.dart';
import 'teacher_login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fondo con gradiente ───────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Círculos decorativos de fondo ─────────────────
          Positioned(
            top: -60,
            right: -60,
            child: _decorCircle(200, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            top: 80,
            right: -30,
            child: _decorCircle(120, Colors.white.withOpacity(0.04)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _decorCircle(240, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: 100,
            right: -20,
            child: _decorCircle(100, Colors.white.withOpacity(0.04)),
          ),

          // ── Contenido principal ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.07),

                  // Logo / mascota
                  _buildHeader()
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .slideY(begin: -0.2, curve: Curves.easeOut),

                  SizedBox(height: size.height * 0.06),

                  // Título y subtítulo
                  _buildTitles()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.1),

                  SizedBox(height: size.height * 0.07),

                  // Tarjeta Estudiante
                  _RoleCard(
                    emoji: '🎒',
                    title: 'Soy Estudiante',
                    subtitle: 'Practica matemáticas\nde forma divertida',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    badgeColor: const Color(0xFF5A52E0),
                    badgeText: 'Para niños',
                    onTap: () => Navigator.of(context).pushReplacement(
                      _fadeRoute(const SplashScreen()),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideX(begin: -0.15, curve: Curves.easeOut),

                  const SizedBox(height: 16),

                  // Tarjeta Profesor
                  _RoleCard(
                    emoji: '🧑‍🏫',
                    title: 'Soy Profesor',
                    subtitle: 'Gestiona estudiantes\ny monitorea su progreso',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    badgeColor: const Color(0xFF00695C),
                    badgeText: 'Portal docente',
                    onTap: () => Navigator.of(context).push(
                      _fadeRoute(const TeacherLoginScreen()),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 550.ms, duration: 600.ms)
                      .slideX(begin: 0.15, curve: Curves.easeOut),

                  const Spacer(),

                  // Pie
                  _buildFooter()
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 500.ms),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Center(
            child: Text('🦉', style: TextStyle(fontSize: 50)),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            'Tutor inteligente de matemáticas',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitles() {
    return Column(
      children: [
        Text(
          'MathMágico',
          style: GoogleFonts.nunito(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '¿Con quién estoy hablando hoy?',
          style: GoogleFonts.nunito(
            fontSize: 16,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.12),
        ),
        const SizedBox(height: 14),
        Text(
          'Universidad Salesiana de Bolivia • 2025',
          style: GoogleFonts.nunito(
            fontSize: 11,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: page,
      ),
    );
  }
}

// ── Tarjeta de rol ─────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Color badgeColor;
  final String badgeText;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.badgeColor,
    required this.badgeText,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji en círculo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 18),

              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.badgeText,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Flecha
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
