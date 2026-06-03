import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import 'home_screen.dart';

class DiagnosticoScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const DiagnosticoScreen({super.key, required this.userId, required this.userName});

  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen>
    with TickerProviderStateMixin {

  List<Map<String, dynamic>> _preguntas = [];
  int _indice = 0;
  final List<Map<String, dynamic>> _respuestas = [];
  bool _cargando = true;
  bool _enviando = false;
  Map<String, dynamic>? _resultado;

  late AnimationController _mascotaCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _mascotaAnim;
  late Animation<Offset> _cardAnim;

  @override
  void initState() {
    super.initState();
    _mascotaCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _mascotaAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _mascotaCtrl, curve: Curves.easeInOut),
    );
    _cardAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut),
    );

    _cargarPreguntas();
  }

  @override
  void dispose() {
    _mascotaCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPreguntas() async {
    final data = await ApiService.getDiagnosticoPreguntas();
    if (data != null && mounted) {
      setState(() {
        _preguntas = List<Map<String, dynamic>>.from(data);
        _cargando = false;
      });
      _cardCtrl.forward();
      _leerPregunta();
    }
  }

  void _leerPregunta() {
    if (_preguntas.isEmpty || _indice >= _preguntas.length) return;
    final audio = _preguntas[_indice]['audio'] ?? _preguntas[_indice]['texto'];
    AudioService.speak(audio);
  }

  Future<void> _responder(bool valor) async {
    final pregunta = _preguntas[_indice];
    _respuestas.add({'pregunta_id': pregunta['id'], 'respuesta': valor});

    if (_indice < _preguntas.length - 1) {
      await _cardCtrl.reverse();
      setState(() => _indice++);
      _cardCtrl.forward();
      _leerPregunta();
    } else {
      await _enviarDiagnostico();
    }
  }

  Future<void> _enviarDiagnostico() async {
    setState(() => _enviando = true);
    final res = await ApiService.submitDiagnostico(
      userId: widget.userId,
      respuestas: _respuestas,
    );
    if (mounted) {
      setState(() {
        _resultado = res;
        _enviando = false;
      });
      if (res != null) {
        AudioService.speak(res['mensaje'] ?? '');
      }
    }
  }

  Color get _colorRiesgo {
    switch (_resultado?['nivel_riesgo']) {
      case 'alto':     return const Color(0xFFE53935);
      case 'moderado': return const Color(0xFFFB8C00);
      default:         return const Color(0xFF43A047);
    }
  }

  String get _iconoRiesgo {
    switch (_resultado?['nivel_riesgo']) {
      case 'alto':     return '🔴';
      case 'moderado': return '🟡';
      default:         return '🟢';
    }
  }

  String get _tituloRiesgo {
    switch (_resultado?['nivel_riesgo']) {
      case 'alto':     return '¡Necesitas apoyo especial!';
      case 'moderado': return '¡Vas aprendiendo!';
      default:         return '¡Vas muy bien!';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return _buildCargando();
    if (_enviando) return _buildEnviando();
    if (_resultado != null) return _buildResultado();
    return _buildPregunta();
  }

  // ── Pantalla de pregunta ─────────────────────────────────────────────────
  Widget _buildPregunta() {
    final pregunta = _preguntas[_indice];
    final progreso = (_indice + 1) / _preguntas.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Barra de progreso ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pregunta ${_indice + 1} de ${_preguntas.length}',
                          style: GoogleFonts.nunito(
                            color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(_indice + 1)}/${_preguntas.length}',
                          style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progreso,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Mascota ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ScaleTransition(
                  scale: _mascotaAnim,
                  child: Column(
                    children: [
                      const Text('🦉', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '¡Responde con honestidad! 😊',
                          style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tarjeta de pregunta ────────────────────────
              Expanded(
                child: SlideTransition(
                  position: _cardAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Emoji ilustrativo
                          Text(
                            pregunta['emoji'] ?? '❓',
                            style: const TextStyle(fontSize: 42),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          // Texto de la pregunta
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              pregunta['texto'] ?? '',
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A237E),
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botón de audio
                          GestureDetector(
                            onTap: _leerPregunta,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7B1FA2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.volume_up, color: Color(0xFF7B1FA2), size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Escuchar',
                                    style: GoogleFonts.nunito(
                                      color: const Color(0xFF7B1FA2),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Botones SÍ / NO ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Row(
                  children: [
                    // NO
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _responder(false),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('❌', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(
                                'NO',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // SÍ
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _responder(true),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF43A047),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF43A047).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('✅', style: TextStyle(fontSize: 28)),
                              const SizedBox(height: 4),
                              Text(
                                'SÍ',
                                style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pantalla de resultado ────────────────────────────────────────────────
  Widget _buildResultado() {
    final actividades = List<String>.from(_resultado?['actividades_recomendadas'] ?? []);
    final dificultades = _resultado?['total_dificultades'] ?? 0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_colorRiesgo.withOpacity(0.8), _colorRiesgo],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Mascota
                const Text('🦉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                // Título
                Text(
                  _iconoRiesgo,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Text(
                  _tituloRiesgo,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Mensaje
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _resultado?['mensaje'] ?? '',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Puntaje
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text(
                        'Dificultades encontradas: $dificultades / 8',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Actividades recomendadas
                if (actividades.isNotEmpty) ...[
                  Text(
                    '🎯 Actividades recomendadas para ti:',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...actividades.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('⭐', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Text(
                            _nombreActividad(a),
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 32),
                // Botón continuar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _colorRiesgo,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      '¡Empezar a practicar! 🚀',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCargando() => Scaffold(
    backgroundColor: const Color(0xFF4A148C),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🦉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Preparando tu diagnóstico...',
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: Colors.white),
        ],
      ),
    ),
  );

  Widget _buildEnviando() => Scaffold(
    backgroundColor: const Color(0xFF4A148C),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🦉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            '¡Calculando tu resultado!',
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: Color(0xFFFFD700)),
        ],
      ),
    ),
  );

  String _nombreActividad(String key) {
    const nombres = {
      'conteo':           'Contar tocando',
      'reconocer_numeros':'Reconocer números',
      'comparar':         'Comparar cantidades',
      'suma_visual':      'Sumar objetos',
      'resta_visual':     'Restar objetos',
      'secuencias':       'Ordenar números',
    };
    return nombres[key] ?? key;
  }
}
