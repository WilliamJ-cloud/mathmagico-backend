import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_theme.dart';
import '../config/constants.dart';
import 'teacher_student_detail_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final String token;

  const TeacherDashboardScreen({
    super.key,
    required this.teacher,
    required this.token,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic> _dashboard = {};
  bool _isLoading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _teacherId => widget.teacher['id'] ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      };

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadStudents(), _loadDashboard()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStudents() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/teachers/$_teacherId/students'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _students = List<Map<String, dynamic>>.from(data['students']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando estudiantes: $e');
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/teachers/$_teacherId/dashboard'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        setState(() => _dashboard = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error cargando dashboard: $e');
    }
  }

  Future<void> _addStudent() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddStudentDialog(),
    );

    if (result == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/teachers/$_teacherId/students'),
        headers: _headers,
        body: jsonEncode(result),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Estudiante agregado exitosamente',
                style: GoogleFonts.nunito()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agregar estudiante',
                style: GoogleFonts.nunito()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(String studentId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('¿Eliminar estudiante?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('¿Deseas eliminar a $name de tu lista?',
            style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: GoogleFonts.nunito()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Eliminar',
                style: GoogleFonts.nunito(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await http.delete(
        Uri.parse(
            '${AppConstants.baseUrl}/teachers/$_teacherId/students/$studentId'),
        headers: _headers,
      );
      _loadData();
    } catch (e) {
      debugPrint('Error eliminando: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${widget.teacher['name'] ?? 'Profesor'}',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              widget.teacher['school'] ?? 'MathMágico',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: const Text('👨‍🏫',
            style: TextStyle(fontSize: 28)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Estadísticas generales
                    _buildStatsRow(),
                    const SizedBox(height: 20),

                    // Header lista estudiantes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mis estudiantes (${_students.length})',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A237E),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addStudent,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Agregar',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de estudiantes
                    _students.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _students.length,
                            itemBuilder: (_, i) => _buildStudentCard(
                              _students[i],
                              i,
                            ),
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('Nuevo estudiante',
            style: GoogleFonts.nunito(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _dashboard['total_students'] ?? _students.length;
    final active = _dashboard['active_this_week'] ?? 0;
    final avgAcc = _dashboard['avg_accuracy'] ?? 0.0;

    return Row(
      children: [
        _buildStatCard('👦', '$total', 'Estudiantes',
            const Color(0xFF1A237E)),
        const SizedBox(width: 10),
        _buildStatCard('🔥', '$active', 'Activos hoy',
            AppColors.success),
        const SizedBox(width: 10),
        _buildStatCard(
            '🎯', '${avgAcc.toStringAsFixed(0)}%', 'Precisión', AppColors.accent),
      ],
    ).animate().fadeIn();
  }

  Widget _buildStatCard(
      String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final accuracy = student['avg_accuracy'] ?? 0.0;
    final sessions = student['total_sessions'] ?? 0;
    final level = student['level'] ?? 1;

    Color accuracyColor = AppColors.error;
    if (accuracy >= 70) accuracyColor = AppColors.success;
    else if (accuracy >= 50) accuracyColor = AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              student['avatar_emoji'] ?? '🦁',
              style: const TextStyle(fontSize: 26),
            ),
          ),
        ),
        title: Text(
          student['name'] ?? 'Estudiante',
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A237E),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student['age']} años • Nivel $level • $sessions sesiones',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Precisión: ',
                  style: GoogleFonts.nunito(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${accuracy.toStringAsFixed(0)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accuracyColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Color(0xFF1A237E)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherStudentDetailScreen(
                    student: student,
                    teacherId: _teacherId,
                    token: widget.token,
                  ),
                ),
              ).then((_) => _loadData()),
              tooltip: 'Ver progreso',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _deleteStudent(
                student['id'],
                student['name'],
              ),
              tooltip: 'Eliminar',
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherStudentDetailScreen(
              student: student,
              teacherId: _teacherId,
              token: widget.token,
            ),
          ),
        ).then((_) => _loadData()),
      ),
    ).animate(delay: Duration(milliseconds: 60 * index)).slideX(begin: 0.1).fadeIn();
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('👦', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'No tienes estudiantes aún',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona "Agregar" para registrar\na tu primer estudiante',
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Diálogo para agregar estudiante ──────────────────────
class _AddStudentDialog extends StatefulWidget {
  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _nameController       = TextEditingController();
  final _gradeController      = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentPhoneController= TextEditingController();
  int    _selectedAge  = 7;
  String _selectedAvatar = '🦁';

  final List<String> _avatars = [
    '🦁','🐱','🐶','🦊','🐻','🐸','🦋','🌟',
    '🐰','🐯','🐼','🦄',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Nuevo estudiante',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(_selectedAvatar,
                    style: const TextStyle(fontSize: 32))),
              ),
            ),
            const SizedBox(height: 12),

            // Nombre estudiante
            _field(_nameController, 'Nombre del estudiante'),
            const SizedBox(height: 10),

            // Grado
            _field(_gradeController, 'Grado (ej: 2do primaria)'),
            const SizedBox(height: 10),

            // Edad
            Text('Edad:', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [6, 7, 8].map((age) {
                final sel = _selectedAge == age;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAge = age),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF1A237E)
                                 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text('$age',
                        style: GoogleFonts.nunito(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : Colors.black87))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Avatar picker
            Text('Avatar:', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _avatars.map((emoji) {
                final sel = _selectedAvatar == emoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAvatar = emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF1A237E).withOpacity(0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? const Color(0xFF1A237E)
                                   : Colors.transparent,
                        width: 2),
                    ),
                    child: Center(child: Text(emoji,
                        style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Separador datos padres
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.family_restroom, size: 18,
                    color: Color(0xFF1A237E)),
                const SizedBox(width: 6),
                Text('Datos del padre/madre/tutor',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A237E), fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 10),

            // Nombre padre
            _field(_parentNameController, 'Nombre completo del tutor',
                icon: Icons.person_outline),
            const SizedBox(height: 10),

            // Celular padre
            _field(_parentPhoneController, 'Numero de celular (WhatsApp)',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone),
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
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, {
              'name':         _nameController.text.trim(),
              'age':          _selectedAge,
              'avatar_emoji': _selectedAvatar,
              'grade':        _gradeController.text.trim(),
              'parent_name':  _parentNameController.text.trim(),
              'parent_phone': _parentPhoneController.text.trim(),
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Agregar',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {IconData? icon,
       TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.nunito(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: const Color(0xFF1A237E))
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Color(0xFF1A237E), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }
}