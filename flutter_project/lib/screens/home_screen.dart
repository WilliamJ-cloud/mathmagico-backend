import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../models/activity_model.dart';
import '../services/audio_service.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/activity_card.dart';
import 'activity_screen.dart';
import 'progress_screen.dart';
import 'achievements_screen.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'parent_report_screen.dart';
import 'welcome_screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Definición de todas las actividades
  final List<ActivityModel> _activities = [
    ActivityModel(
      id: 'suma_visual',
      title: 'Sumar objetos',
      description: 'Suma grupos de objetos coloridos',
      type: ActivityType.sumaVisual,
      difficulty: Difficulty.easy,
      emoji: '🍎',
      color: const Color(0xFFE8F4FF),
      pointsReward: 50,
    ),
    ActivityModel(
      id: 'conteo',
      title: 'Contar tocando',
      description: 'Toca cada objeto para contarlo',
      type: ActivityType.conteo,
      difficulty: Difficulty.easy,
      emoji: '✋',
      color: const Color(0xFFF0FFF4),
      pointsReward: 40,
    ),
    ActivityModel(
      id: 'comparar',
      title: 'Comparar cantidades',
      description: '¿Cuál grupo tiene más?',
      type: ActivityType.comparar,
      difficulty: Difficulty.easy,
      emoji: '📏',
      color: const Color(0xFFFFF0F0),
      pointsReward: 45,
    ),
    ActivityModel(
      id: 'secuencias',
      title: 'Ordenar números',
      description: 'Pon los números en orden',
      type: ActivityType.secuencias,
      difficulty: Difficulty.medium,
      emoji: '🔢',
      color: const Color(0xFFFFFBF0),
      pointsReward: 60,
    ),
    ActivityModel(
      id: 'reconocer_numeros',
      title: 'Reconocer números',
      description: 'Identifica el número que ves',
      type: ActivityType.reconocerNumeros,
      difficulty: Difficulty.medium,
      emoji: '👁️',
      color: const Color(0xFFF5F0FF),
      pointsReward: 55,
    ),
    ActivityModel(
      id: 'resta_visual',
      title: 'Restar objetos',
      description: 'Quita objetos y cuenta los que quedan',
      type: ActivityType.restaVisual,
      difficulty: Difficulty.hard,
      emoji: '➖',
      color: const Color(0xFFFFF5F0),
      pointsReward: 70,
    ),
    ActivityModel(
      id: 'subitizacion',
      title: 'Ver y contar',
      description: '¿Cuántos puntos ves? ¡Responde rápido!',
      type: ActivityType.subitizacion,
      difficulty: Difficulty.easy,
      emoji: '👀',
      color: const Color(0xFFF0FFF8),
      pointsReward: 45,
    ),
    ActivityModel(
      id: 'linea_numerica',
      title: 'Línea numérica',
      description: '¿Dónde va ese número en la línea?',
      type: ActivityType.lineaNumerica,
      difficulty: Difficulty.medium,
      emoji: '📍',
      color: const Color(0xFFF5F0FF),
      pointsReward: 55,
    ),
    ActivityModel(
      id: 'descomposicion',
      title: 'Partes del número',
      description: '¿Qué número falta para completar?',
      type: ActivityType.descomposicion,
      difficulty: Difficulty.medium,
      emoji: '🔧',
      color: const Color(0xFFFFFBE6),
      pointsReward: 60,
    ),
    ActivityModel(
      id: 'trazar_numeros',
      title: 'Trazar números',
      description: 'Sigue los puntos para dibujar el número',
      type: ActivityType.trazarNumeros,
      difficulty: Difficulty.easy,
      emoji: '✏️',
      color: const Color(0xFFECF8FF),
      pointsReward: 50,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _greetUser();
  }

  void _greetUser() {
    final user = context.read<UserProvider>().user;
    if (user != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        context.read<AudioService>().speak(
          '¡Hola ${user.name}! ¿Qué vamos a aprender hoy?',
        );
      });
    }
  }

  void _openActivity(ActivityModel activity) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: ActivityScreen(activity: activity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header principal
            _buildHeader(user),

            // Contenido según tab
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildActivitiesTab(),
                  const ProgressScreen(),
                  const AchievementsScreen(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom navigation
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primaryLight.withOpacity(0.3),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon:
                  Icon(Icons.bar_chart, color: AppColors.primary),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon:
                  Icon(Icons.emoji_events, color: AppColors.primary),
              label: 'Logros',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon:
                  Icon(Icons.settings, color: AppColors.primary),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          // Avatar del usuario
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: Center(
              child: Text(
                user?.avatarEmoji ?? '🦁',
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info del usuario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola de nuevo!',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                Text(
                  user?.name ?? 'Amigo',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                // Estrellas / nivel
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        Icons.star,
                        size: 16,
                        color: i < (user?.calculatedLevel ?? 1)
                            ? AppColors.accent
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Nivel ${user?.calculatedLevel ?? 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Puntos
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 18)),
                Text(
                  '${user?.totalPoints ?? 0}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    final user = context.watch<UserProvider>().user;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner motivacional ──────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFFDE7)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.35), width: 1.5),
            ),
            child: Row(
              children: [
                const Text('🦉', style: TextStyle(fontSize: 42)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, ${user?.name ?? 'amigo'}! 👋',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿Qué vamos a practicar hoy?',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideX(begin: -0.15).fadeIn(),

          const SizedBox(height: 18),

          // ── Título sección ───────────────────────────────
          Row(
            children: [
              Container(
                width: 6,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Actividades',
                style: GoogleFonts.nunito(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_activities.length}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 14),

          // Grid de actividades
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.95,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _activities.length,
            itemBuilder: (context, index) {
              return ActivityCard(
                activity: _activities[index],
                onTap: () => _openActivity(_activities[index]),
              )
                  .animate(delay: Duration(milliseconds: 80 * index))
                  .slideY(begin: 0.3)
                  .fadeIn();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final user = context.watch<UserProvider>().user;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Perfil ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C8FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withOpacity(0.6), width: 2.5),
                  ),
                  child: Center(
                    child: Text(user?.avatarEmoji ?? '🦁',
                        style: const TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Usuario',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${user?.age ?? 6} años  •  Nivel ${user?.calculatedLevel ?? 1}',
                        style: GoogleFonts.nunito(
                            fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '⭐  ${user?.totalPoints ?? 0} puntos totales',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
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
          ).animate().fadeIn().slideY(begin: 0.1),

          const SizedBox(height: 28),

          Text(
            'Opciones',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          // ── Reporte para padres ──────────────────────────
          _settingsCard(
            icon: Icons.insert_chart_outlined_rounded,
            iconColor: const Color(0xFF6C63FF),
            bgColor: const Color(0xFFF0EEFF),
            title: 'Reporte para padres',
            subtitle: 'Ver progreso detallado y compartir con la familia',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParentReportScreen()),
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          // ── ID de estudiante ─────────────────────────────
          _buildStudentIdCard(user).animate().fadeIn(delay: 140.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          // ── Vincular con Profesor ────────────────────────
          _settingsCard(
            icon: Icons.link_rounded,
            iconColor: const Color(0xFF7B1FA2),
            bgColor: const Color(0xFFF3E5F5),
            title: 'Vincular con mi Profesor',
            subtitle: 'Ingresar el código que te dio tu profesor',
            onTap: () => _showLinkDialog(user),
          ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          // ── Cambiar usuario ──────────────────────────────
          _settingsCard(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF00897B),
            bgColor: const Color(0xFFE0F2F1),
            title: 'Cambiar usuario',
            subtitle: 'Cerrar sesión y entrar con otro perfil',
            onTap: _changeUser,
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

          const SizedBox(height: 10),

          // ── Salir al inicio ──────────────────────────────
          _settingsCard(
            icon: Icons.home_rounded,
            iconColor: const Color(0xFF1A237E),
            bgColor: const Color(0xFFE8EAF6),
            title: 'Pantalla de inicio',
            subtitle: 'Volver a la selección de Estudiante / Profesor',
            onTap: () => Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (_, animation, __) => FadeTransition(
                  opacity: animation,
                  child: const WelcomeScreen(),
                ),
              ),
              (route) => false,
            ),
          ).animate().fadeIn(delay: 260.ms).slideX(begin: -0.1),

          const SizedBox(height: 32),

          // ── Info app ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('🦉', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  'MathMágico v1.0',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tutor inteligente para niños con discalculia',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Universidad Salesiana de Bolivia • 2025',
                  style: GoogleFonts.nunito(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 350.ms),
        ],
      ),
    );
  }

  Widget _settingsCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }

Future<void> _changeUser() async {
  // Mostrar confirmación
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        '¿Cambiar usuario?',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: Text(
        'Se cerrará la sesión actual. ¿Continuar?',
        style: GoogleFonts.nunito(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: GoogleFonts.nunito()),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Sí, cambiar',
            style: GoogleFonts.nunito(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirm == true && mounted) {
    // Borrar usuario guardado
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');

    // Desloguear
    context.read<UserProvider>().logout();

    // Ir a pantalla de bienvenida
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const WelcomeScreen(),
        ),
      ),
      (route) => false,
    );
  }
}

  // ── ID de estudiante card ─────────────────────────────
  Widget _buildStudentIdCard(UserModel? user) {
    final id = user?.id ?? '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined,
              color: Color(0xFFFF8F00), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tu código de estudiante',
                style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(id,
                style: GoogleFonts.nunito(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20),
          color: AppColors.primary,
          tooltip: 'Copiar código',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Código copiado',
                    style: GoogleFonts.nunito()),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      ]),
    );
  }

  // ── Vincular con Profesor ─────────────────────────────
  Future<void> _showLinkDialog(UserModel? currentUser) async {
    final controller = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('Vincular con Profesor',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Pide a tu profesor tu Código de Estudiante e ingrésalo aquí.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Código de estudiante',
                labelStyle: GoogleFonts.nunito(),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.link_rounded),
              ),
              style: GoogleFonts.nunito(),
            ),
            if (isLoading) ...[
              const SizedBox(height: 12),
              const CircularProgressIndicator(),
            ],
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: GoogleFonts.nunito()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = controller.text.trim();
                      if (code.isEmpty) return;
                      setS(() => isLoading = true);

                      // Verificar que el código existe en el backend
                      final data = await ApiService.get('/users/$code');
                      setS(() => isLoading = false);

                      if (data == null || data['error'] == true) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Código no encontrado. Verifica con tu profesor.',
                                  style: GoogleFonts.nunito()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }

                      // Crear el modelo con el ID del profesor
                      final linked = UserModel.fromJson({
                        ...data,
                        'activityDates': currentUser?.activityDates ?? [],
                        'skillLevels': data['skill_levels'] ?? currentUser?.skillLevels ?? {},
                        'avatarEmoji': data['avatar_emoji'] ?? currentUser?.avatarEmoji ?? '🦁',
                        'totalPoints': data['total_points'] ?? currentUser?.totalPoints ?? 0,
                        'level': data['level'] ?? currentUser?.level ?? 1,
                        'achievements': data['achievements'] ?? currentUser?.achievements ?? [],
                        'createdAt': data['created_at'] ?? DateTime.now().toIso8601String(),
                      });

                      await StorageService.instance.saveUser(linked);
                      await StorageService.instance.saveCurrentUserId(linked.id);

                      if (mounted) {
                        context.read<UserProvider>().setUser(linked);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡Vinculado correctamente con ${linked.name}! 🎉',
                                style: GoogleFonts.nunito()),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              child: Text('Vincular',
                  style: GoogleFonts.nunito(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}