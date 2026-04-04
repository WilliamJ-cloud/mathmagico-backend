import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _showRegistration = false;
  bool _isLoading = false;
  bool _showSearch = false;         // toggle: nuevo vs buscar cuenta
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  int _selectedAge = 6;
  String _selectedAvatar = '🦁';

  final List<String> _avatars = [
    '🦁', '🐱', '🐶', '🦊', '🐻', '🐸', '🦋', '🌟'
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  Future<void> _checkExistingUser() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final userId = await StorageService.instance.getCurrentUserId();
    if (userId != null && mounted) {
      // Intentar cargar desde local storage
      UserModel? user = await StorageService.instance.getUser(userId);

      // Siempre sincronizar con el backend para datos frescos
      final backendData = await ApiService.get('/users/$userId');
      if (backendData != null && backendData['error'] != true) {
        final skillsRaw = backendData['skill_levels'] as Map? ?? {};
        final syncedSkills = skillsRaw.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()));

        if (user != null) {
          // Merge: backend gana en puntos/nivel/logros, local conserva activityDates
          user = user.copyWith(
            totalPoints: (backendData['total_points'] as num?)?.toInt() ?? user.totalPoints,
            level: (backendData['level'] as num?)?.toInt() ?? user.level,
            achievements: List<String>.from(backendData['achievements'] ?? user.achievements),
            skillLevels: syncedSkills.isNotEmpty ? syncedSkills : user.skillLevels,
          );
        } else {
          // No hay datos locales — construir desde backend
          user = UserModel.fromJson(backendData);
        }
        await StorageService.instance.saveUser(user);
        await StorageService.instance.saveCurrentUserId(user.id);
      }

      if (user != null && mounted) {
        context.read<UserProvider>().setUser(user);
        _goToHome();
        return;
      }
    }
    if (mounted) {
      setState(() => _showRegistration = true);
    }
  }

  // Buscar cuenta por nombre
  Future<void> _searchByName() async {
    final name = _searchController.text.trim();
    if (name.length < 2) return;
    setState(() { _isLoading = true; _searchResults = []; });

    final data = await ApiService.get('/users/search?name=${Uri.encodeComponent(name)}');
    setState(() => _isLoading = false);

    if (data == null || data['error'] == true) {
      setState(() => _searchResults = []);
      return;
    }

    // El endpoint devuelve una lista
    final list = data['data'] as List? ?? [];
    setState(() => _searchResults = List<Map<String, dynamic>>.from(list));
  }

  // Recuperar cuenta seleccionada
  Future<void> _loginWithFound(Map<String, dynamic> userData) async {
    final user = UserModel.fromJson(userData);
    await StorageService.instance.saveUser(user);
    await StorageService.instance.saveCurrentUserId(user.id);
    if (mounted) {
      context.read<UserProvider>().setUser(user);
      context.read<AudioService>().speak(
        '¡Hola ${user.name}! Bienvenido de nuevo a MathMágico.',
      );
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe tu nombre 😊')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final user = await apiService.registerUser(
        name: _nameController.text.trim(),
        age: _selectedAge,
        avatarEmoji: _selectedAvatar,
      );

      if (user != null && mounted) {
        final userModel = UserModel.fromJson(user);
        await StorageService.instance.saveUser(userModel);
        await StorageService.instance.saveCurrentUserId(userModel.id);
        context.read<UserProvider>().setUser(userModel);
        context.read<AudioService>().speak(
          '¡Hola ${userModel.name}! Bienvenido a MathMágico. ¡Vamos a aprender matemáticas!',
        );
        _goToHome();
      } else {
        // Modo offline: crear usuario local
        _registerOffline();
      }
    } catch (e) {
      _registerOffline();
    }
  }

  void _registerOffline() async {
    final user = UserModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      age: _selectedAge,
      avatarEmoji: _selectedAvatar,
      createdAt: DateTime.now(),
    );
    await StorageService.instance.saveUser(user);
    await StorageService.instance.saveCurrentUserId(user.id);
    if (mounted) {
      context.read<UserProvider>().setUser(user);
      context.read<AudioService>().speak(
        '¡Hola ${user.name}! Vamos a aprender matemáticas.',
      );
      _goToHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _showRegistration
              ? _buildRegistration()
              : _buildSplash(),
        ),
      ),
    );
  }

  Widget _buildSplash() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mascota
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const Center(
              child: Text('🦉', style: TextStyle(fontSize: 50)),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.5, 0.5))
              .then()
              .shake(hz: 2, duration: 500.ms),

          const SizedBox(height: 24),

          Text(
            'MathMágico',
            style: GoogleFonts.nunito(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 8),

          Text(
            'Tu tutor de matemáticas mágico ✨',
            style: GoogleFonts.nunito(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 48),

          // Indicador de carga
          const CircularProgressIndicator(
            color: Colors.white,
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildRegistration() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Header
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Center(
              child: Text(
                _showSearch ? '🔍' : _selectedAvatar,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn(),

          const SizedBox(height: 16),

          Text(
            _showSearch ? '¿Cuál es tu nombre?' : '¡Hola! ¿Cómo te llamas?',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // ── Card según modo ───────────────────────────────
          if (_showSearch) ...[
            // Buscador por nombre
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Escribe tu nombre:',
                    style: GoogleFonts.nunito(
                        fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchByName(),
                      decoration: InputDecoration(
                        hintText: 'Tu nombre...',
                        hintStyle: GoogleFonts.nunito(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _searchByName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.search_rounded,
                            color: Colors.white),
                  ),
                ]),

                // Resultados
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Selecciona tu cuenta:',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._searchResults.map((u) => GestureDetector(
                    onTap: () => _loginWithFound(u),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Text(u['avatar_emoji'] ?? '🦁',
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(u['name'] ?? '',
                                style: GoogleFonts.nunito(
                                    fontSize: 16, fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary)),
                            Text('${u['age'] ?? ''} años  •  Nivel ${u['level'] ?? 1}  •  ⭐ ${u['total_points'] ?? 0} pts',
                                style: GoogleFonts.nunito(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.primary),
                      ]),
                    ),
                  )),
                ] else if (!_isLoading && _searchController.text.length >= 2) ...[
                  const SizedBox(height: 10),
                  Text('No encontré ninguna cuenta con ese nombre.',
                      style: GoogleFonts.nunito(
                          fontSize: 13, color: AppColors.textHint)),
                ],
              ]),
            ).animate().slideY(begin: 0.3).fadeIn(delay: 200.ms),

            const SizedBox(height: 14),
            TextButton(
              onPressed: () => setState(() {
                _showSearch = false;
                _searchController.clear();
                _searchResults = [];
              }),
              child: Text('← Crear cuenta nueva',
                  style: GoogleFonts.nunito(
                      color: Colors.white70, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ] else ...[

          // Card de registro
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre
                Text(
                  'Mi nombre es:',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu nombre...',
                    hintStyle: GoogleFonts.nunito(
                      color: AppColors.textHint,
                      fontSize: 18,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),

                const SizedBox(height: 20),

                // Edad
                Text(
                  'Mi edad:',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [6, 7, 8].map((age) {
                    final isSelected = _selectedAge == age;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAge = age),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$age',
                            style: GoogleFonts.nunito(
                              fontSize: 26,
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

                const SizedBox(height: 20),

                // Avatar
                Text(
                  'Elige tu personaje:',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _avatars.map((emoji) {
                    final isSelected = _selectedAvatar == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryLight.withOpacity(0.3)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.3).fadeIn(delay: 300.ms),

          const SizedBox(height: 24),

          // Botón de inicio
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: AppColors.textPrimary)
                  : Text(
                      '¡Empezar a aprender! 🚀',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ).animate().slideY(begin: 0.5).fadeIn(delay: 500.ms),

          const SizedBox(height: 12),

          // ── Ya tengo cuenta ──────────────────────────────
          GestureDetector(
            onTap: () => setState(() {
              _showSearch = true;
              _nameController.clear();
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_search_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿Ya jugaste antes? 🎮',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Busca tu cuenta por nombre',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: AppColors.primary, size: 16),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),

          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (_, animation, __) => FadeTransition(
                  opacity: animation,
                  child: const WelcomeScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white60, size: 16),
            label: Text(
              'Volver al inicio',
              style: GoogleFonts.nunito(
                color: Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ).animate().fadeIn(delay: 700.ms),

          ], // end else
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}