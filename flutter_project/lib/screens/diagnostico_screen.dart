import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
  String? _seleccionada;
  bool _respondida = false;
  final List<Map<String, dynamic>> _respuestas = [];
  bool _cargando = true;
  bool _enviando = false;
  Map<String, dynamic>? _resultado;

  late AnimationController _mascotaCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _mascotaAnim;
  late Animation<Offset> _cardAnim;

  // Colores por categoría
  static const _coloresCat = {
    'reconocimiento':   Color(0xFF1565C0),
    'conteo':           Color(0xFF2E7D32),
    'comparacion':      Color(0xFFE65100),
    'operaciones':      Color(0xFF6A1B9A),
    'secuencias':       Color(0xFF00838F),
    'relacion_cantidad':Color(0xFFC62828),
  };

  static const _iconosCat = {
    'reconocimiento':   '🔢',
    'conteo':           '🖐️',
    'comparacion':      '⚖️',
    'operaciones':      '➕',
    'secuencias':       '📊',
    'relacion_cantidad':'🔗',
  };

  @override
  void initState() {
    super.initState();
    _mascotaCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _mascotaAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _mascotaCtrl, curve: Curves.easeInOut));
    _cardAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut));
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
    context.read<AudioService>().speak(_preguntas[_indice]['audio'] ?? '');
  }

  Color get _colorActual {
    if (_preguntas.isEmpty || _indice >= _preguntas.length) return const Color(0xFF1565C0);
    return _coloresCat[_preguntas[_indice]['categoria']] ?? const Color(0xFF1565C0);
  }

  void _seleccionar(String opcion) {
    if (_respondida) return;
    setState(() {
      _seleccionada = opcion;
      _respondida = true;
    });
    // Espera 1 segundo para mostrar feedback, luego avanza
    Future.delayed(const Duration(milliseconds: 1000), _siguiente);
  }

  Future<void> _siguiente() async {
    if (_seleccionada == null) return;
    _respuestas.add({
      'pregunta_id': _preguntas[_indice]['id'],
      'respuesta': _seleccionada,
    });

    if (_indice < _preguntas.length - 1) {
      await _cardCtrl.reverse();
      setState(() {
        _indice++;
        _seleccionada = null;
        _respondida = false;
      });
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
      setState(() { _resultado = res; _enviando = false; });
      if (res != null) {
        context.read<AudioService>().speak(res['mensaje'] ?? '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando)  return _buildCargando();
    if (_enviando)  return _buildEnviando();
    if (_resultado != null) return _buildResultado();
    return _buildPregunta();
  }

  // ── Pantalla de pregunta ──────────────────────────────────────────────────
  Widget _buildPregunta() {
    final pregunta  = _preguntas[_indice];
    final opciones  = List<String>.from(pregunta['opciones'] ?? []);
    final correcta  = pregunta['correcta'] as String;
    final categoria = pregunta['categoria'] as String? ?? '';
    final progreso  = (_indice + 1) / _preguntas.length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_colorActual, _colorActual.withOpacity(0.7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Categoría
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_iconosCat[categoria] ?? '📝'} ${_nombreCategoria(categoria)}',
                            style: GoogleFonts.nunito(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${_indice + 1} / ${_preguntas.length}',
                          style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progreso,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Mascota ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ScaleTransition(
                  scale: _mascotaAnim,
                  child: const Text('🦉', style: TextStyle(fontSize: 52)),
                ),
              ),

              // ── Tarjeta de pregunta ───────────────────────
              Expanded(
                child: SlideTransition(
                  position: _cardAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Pregunta
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15, offset: const Offset(0, 6),
                              )],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  pregunta['emoji'] ?? '',
                                  style: const TextStyle(fontSize: 32),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  pregunta['texto'] ?? '',
                                  style: GoogleFonts.nunito(
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                    color: _colorActual, height: 1.3),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                // Botón audio
                                GestureDetector(
                                  onTap: _leerPregunta,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _colorActual.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.volume_up, color: _colorActual, size: 18),
                                        const SizedBox(width: 4),
                                        Text('Escuchar', style: GoogleFonts.nunito(
                                          color: _colorActual, fontWeight: FontWeight.w700, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Opciones ──────────────────────
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.2,
                            children: opciones.map((op) {
                              final esSeleccionada = _seleccionada == op;
                              final esCorrecta     = op == correcta;
                              Color bgColor = Colors.white;
                              Color textColor = _colorActual;
                              Color borderColor = _colorActual.withOpacity(0.3);
                              String prefijo = '';

                              if (_respondida) {
                                if (esCorrecta) {
                                  bgColor = const Color(0xFF43A047);
                                  textColor = Colors.white;
                                  borderColor = const Color(0xFF43A047);
                                  prefijo = '✅ ';
                                } else if (esSeleccionada) {
                                  bgColor = const Color(0xFFE53935);
                                  textColor = Colors.white;
                                  borderColor = const Color(0xFFE53935);
                                  prefijo = '❌ ';
                                } else {
                                  bgColor = Colors.white.withOpacity(0.5);
                                  textColor = Colors.grey;
                                }
                              }

                              return GestureDetector(
                                onTap: () => _seleccionar(op),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor, width: 2),
                                    boxShadow: esSeleccionada ? [BoxShadow(
                                      color: bgColor.withOpacity(0.4),
                                      blurRadius: 8, offset: const Offset(0, 4),
                                    )] : [],
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '$prefijo$op',
                                        style: GoogleFonts.nunito(
                                          fontSize: 15, fontWeight: FontWeight.w800,
                                          color: textColor),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pantalla de resultado ─────────────────────────────────────────────────
  Widget _buildResultado() {
    final porcentaje  = (_resultado?['porcentaje'] as num?)?.toDouble() ?? 0;
    final correctas   = _resultado?['correctas'] as int? ?? 0;
    final total       = _resultado?['total'] as int? ?? 15;
    final nivel       = _resultado?['nivel_riesgo'] as String? ?? '';
    final etiqueta    = _resultado?['etiqueta_nivel'] as String? ?? '';
    final debilidades = List<String>.from(_resultado?['debilidades'] ?? []);
    final actividades = List<String>.from(_resultado?['actividades_recomendadas'] ?? []);
    final mensaje     = _resultado?['mensaje'] as String? ?? '';

    final color = _colorNivel(nivel);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Text('🦉', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 10),

                // ── Puntaje circular ──────────────────────
                Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${porcentaje.toStringAsFixed(0)}%',
                        style: GoogleFonts.nunito(
                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                      Text('$correctas/$total correctas',
                        style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Nivel ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(etiqueta,
                    style: GoogleFonts.nunito(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Escala visual ─────────────────────────
                _buildEscala(porcentaje),

                const SizedBox(height: 16),

                // ── Mensaje ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(mensaje,
                    style: GoogleFonts.nunito(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ),

                // ── Áreas de dificultad ───────────────────
                if (debilidades.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('⚠️ Áreas a reforzar:',
                      style: GoogleFonts.nunito(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  ...debilidades.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Text('📌', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d,
                          style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                      ]),
                    ),
                  )),
                ],

                // ── Actividades recomendadas ──────────────
                if (actividades.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('🎯 Actividades recomendadas:',
                      style: GoogleFonts.nunito(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: actividades.map((a) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('⭐ ${_nombreActividad(a)}',
                        style: GoogleFonts.nunito(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    )).toList(),
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('¡Empezar a practicar! 🚀',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscala(double porcentaje) {
    final niveles = [
      {'label': '<50%\nAlto', 'color': const Color(0xFFE53935), 'min': 0.0, 'max': 50.0},
      {'label': '50-69%\nModerado', 'color': const Color(0xFFFB8C00), 'min': 50.0, 'max': 69.0},
      {'label': '70-84%\nLeve', 'color': const Color(0xFFFDD835), 'min': 70.0, 'max': 84.0},
      {'label': '85-100%\nSin indicadores', 'color': const Color(0xFF43A047), 'min': 85.0, 'max': 100.0},
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Escala de referencia (Butterworth):',
            style: GoogleFonts.nunito(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: niveles.map((n) {
              final isActive = porcentaje >= (n['min'] as double) &&
                  (porcentaje <= (n['max'] as double) || n['max'] as double == 100.0);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: n['color'] as Color,
                    borderRadius: BorderRadius.circular(8),
                    border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Text(n['label'] as String,
                    style: GoogleFonts.nunito(
                      color: Colors.white, fontSize: 9,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w600),
                    textAlign: TextAlign.center),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _colorNivel(String nivel) {
    switch (nivel) {
      case 'alto':           return const Color(0xFFB71C1C);
      case 'moderado':       return const Color(0xFFE65100);
      case 'leve':           return const Color(0xFFF57F17);
      default:               return const Color(0xFF1B5E20);
    }
  }

  Widget _buildCargando() => Scaffold(
    backgroundColor: const Color(0xFF1565C0),
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🦉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 20),
        Text('Preparando tu diagnóstico...',
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: Colors.white),
      ],
    )),
  );

  Widget _buildEnviando() => Scaffold(
    backgroundColor: const Color(0xFF1565C0),
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🦉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 20),
        Text('Calculando tu resultado...',
          style: GoogleFonts.nunito(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: Color(0xFFFFD700)),
      ],
    )),
  );

  String _nombreCategoria(String cat) {
    const nombres = {
      'reconocimiento':    'Reconocimiento',
      'conteo':            'Conteo',
      'comparacion':       'Comparación',
      'operaciones':       'Operaciones',
      'secuencias':        'Secuencias',
      'relacion_cantidad': 'Número-Cantidad',
    };
    return nombres[cat] ?? cat;
  }

  String _nombreActividad(String key) {
    const nombres = {
      'conteo':            'Contar tocando',
      'reconocer_numeros': 'Reconocer números',
      'comparar':          'Comparar cantidades',
      'suma_visual':       'Sumar objetos',
      'resta_visual':      'Restar objetos',
      'secuencias':        'Ordenar números',
    };
    return nombres[key] ?? key;
  }
}
