import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'models/user_model.dart';
import 'models/progress_model.dart';
import 'services/server_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fijar orientación vertical
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cargar URL del servidor guardada (o usar la por defecto)
  await ServerConfig.load();

  // Inicializar base de datos local
  await StorageService.instance.init();

  runApp(const MathMagicoApp());
}

class MathMagicoApp extends StatelessWidget {
  const MathMagicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        Provider(create: (_) => ApiService()),
        Provider(create: (_) => AudioService()),
      ],
      child: MaterialApp(
        title: 'MathMágico',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const WelcomeScreen(),
      ),
    );
  }
}
