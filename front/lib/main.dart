import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'screens/face_scan_screen.dart';
import 'screens/ingresar_scan_screen.dart';
import 'screens/register_scan_screen.dart';
import 'screens/welcome_screen.dart';

// Lista global de cámaras disponibles
late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar las cámaras
  try {
    cameras = await availableCameras();
  } catch (e) {
    print('Error al inicializar las cámaras: $e');
    cameras = [];
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Reconocimiento Facial',
      theme: ThemeData(
        // Definir el tema global
        primaryColor: const Color(0xFF147DFE),
        scaffoldBackgroundColor: const Color(0xFF0A192F),
        textTheme: GoogleFonts.changaTextTheme(
          Theme.of(context).textTheme.copyWith(
                bodyLarge: GoogleFonts.changa(color: Colors.white70, fontSize: 18),
                bodyMedium: GoogleFonts.changa(color: Colors.white70, fontSize: 16),
                titleLarge: GoogleFonts.changa(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                titleMedium: GoogleFonts.changa(color: Colors.white, fontSize: 20),
              ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF147DFE), // Color por defecto para botones
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: GoogleFonts.changa(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      initialRoute: '/face_scan',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/face_scan':
            return MaterialPageRoute(builder: (_) => const FaceScanScreen());
          case '/ingresar':
            return MaterialPageRoute(builder: (_) => const IngresarScanScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScanScreen());
          case '/welcome':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => WelcomeScreen(
                username: args?['username'] as String?,
              ),
            );
          default:
            return MaterialPageRoute(builder: (_) => const FaceScanScreen());
        }
      },
    );
  }
}