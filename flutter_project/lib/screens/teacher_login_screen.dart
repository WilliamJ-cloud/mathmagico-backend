import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/server_config.dart';
import 'teacher_dashboard_screen.dart';
import 'welcome_screen.dart';

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  // Controladores — TODOS inicializados vacíos (nunca null)
  final _nameCtrl     = TextEditingController(text: '');
  final _schoolCtrl   = TextEditingController(text: '');
  final _emailCtrl    = TextEditingController(text: '');
  final _passCtrl     = TextEditingController(text: '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Registro ──────────────────────────────────────────
  Future<void> _register() async {
    setState(() { _loading = true; _error = null; });

    // Validar campos obligatorios
    final name   = _nameCtrl.text.trim();
    final school = _schoolCtrl.text.trim();
    final email  = _emailCtrl.text.trim();
    final pass   = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || name.isEmpty) {
      setState(() {
        _error = 'Por favor completa todos los campos obligatorios';
        _loading = false;
      });
      return;
    }

    try {
      final response = await ApiService.post(
        '/teachers/register',
        {
          'name':     name.isEmpty     ? 'Profesor' : name,
          'school':   school.isEmpty   ? ''         : school,
          'email':    email,
          'password': pass,
        },
      );

      if (!mounted) return;

      if (response != null && response['teacher'] != null) {
        final teacher = Map<String, dynamic>.from(response['teacher']);
        final token   = response['token']?.toString() ?? '';
        _goToDashboard(teacher, token);
      } else {
        setState(() {
          _error = response?['detail']?.toString()
              ?? 'Error al registrar. Intenta de nuevo.';
        });
      }
    } catch (e) {
      setState(() { _error = 'Error de conexión: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  // ── Login ─────────────────────────────────────────────
  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });

    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() {
        _error = 'Ingresa tu correo y contraseña';
        _loading = false;
      });
      return;
    }

    try {
      final response = await ApiService.post(
        '/teachers/login',
        {
          'email':    email,
          'password': pass,
        },
      );

      if (!mounted) return;

      if (response != null && response['teacher'] != null) {
        final teacher = Map<String, dynamic>.from(response['teacher']);
        final token   = response['token']?.toString() ?? '';
        _goToDashboard(teacher, token);
      } else {
        setState(() {
          _error = response?['detail']?.toString()
              ?? 'Correo o contraseña incorrectos.';
        });
      }
    } catch (e) {
      setState(() { _error = 'Error de conexión. Verifica que el servidor esté corriendo.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _showServerConfig() async {
    final ctrl = TextEditingController(text: ServerConfig.baseUrl);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('URL del servidor',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Ingresa la dirección del servidor backend.\n'
            'Ejemplos:\n'
            '• WiFi local: http://192.168.0.7:8000/api/v1\n'
            '• Ngrok: https://xxxx.ngrok-free.app/api/v1',
            style: GoogleFonts.nunito(
                fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: GoogleFonts.nunito(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'URL del servidor',
              labelStyle: GoogleFonts.nunito(fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link, size: 18),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await ServerConfig.reset();
              Navigator.pop(ctx);
              if (mounted) setState(() => _error = null);
            },
            child: Text('Restablecer', style: GoogleFonts.nunito(
                color: Colors.red.shade400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await ServerConfig.save(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() => _error = null);
            },
            child: Text('Guardar',
                style: GoogleFonts.nunito(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goToDashboard(Map<String, dynamic> teacher, String token) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TeacherDashboardScreen(
          teacher: teacher,
          token: token,
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🧑‍🏫', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MathMágico',
                style: GoogleFonts.nunito(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                'Portal del Profesor',
                style: GoogleFonts.nunito(
                  fontSize: 16, color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),

              // Card del formulario
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _tab('Iniciar sesión', _isLogin, () {
                            setState(() { _isLogin = true; _error = null; });
                          }),
                          _tab('Registrarse', !_isLogin, () {
                            setState(() { _isLogin = false; _error = null; });
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campos registro extra
                    if (!_isLogin) ...[
                      _field(
                        ctrl: _nameCtrl,
                        label: 'Nombre completo',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        ctrl: _schoolCtrl,
                        label: 'Institución educativa',
                        icon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Email
                    _field(
                      ctrl: _emailCtrl,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Contraseña
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_showPassword,
                      style: GoogleFonts.nunito(fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: GoogleFonts.nunito(fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline,
                            size: 20, color: Color(0xFF1A237E)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20, color: Colors.grey,
                          ),
                          onPressed: () => setState(
                              () => _showPassword = !_showPassword),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: Color(0xFF1A237E), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade400, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Botón acción
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : (_isLogin ? _login : _register),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                                style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Configurar servidor ───────────────────────
              TextButton.icon(
                onPressed: _showServerConfig,
                icon: const Icon(Icons.settings_ethernet,
                    color: Colors.white38, size: 16),
                label: Text(
                  'Configurar servidor',
                  style: GoogleFonts.nunito(
                      color: Colors.white38, fontSize: 12),
                ),
              ),

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
                icon: const Icon(Icons.arrow_back,
                    color: Colors.white70, size: 18),
                label: Text(
                  'Volver al inicio',
                  style: GoogleFonts.nunito(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────
  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A237E) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: active ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.nunito(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1A237E)),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF1A237E), width: 1.5),
        ),
      ),
    );
  }
}