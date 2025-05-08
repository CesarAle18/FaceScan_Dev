import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/face_recognition_service.dart';

class WelcomeScreen extends StatefulWidget {
  final String? username;

  const WelcomeScreen({Key? key, this.username}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isProcessing = false;

  // Función para manejar el cierre de sesión
  void _logout() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    // Redirigir a la pantalla principal
    Navigator.pushNamedAndRemoveUntil(context, '/face_scan', (route) => false);

    setState(() {
      _isProcessing = false;
    });
  }

  // Función placeholder para el botón de generar reporte (sin funcionalidad por ahora)
  void _generateReport() {
    // Sin funcionalidad por ahora, como especificado
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de bienvenida
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 20),

                // Mensaje de bienvenida personalizado
                Text(
                  '¡Bienvenido${widget.username != null ? ', ${widget.username}' : ''}!',
                  style: GoogleFonts.changa(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Botón Cerrar sesión
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Cerrar sesión',
                              style: GoogleFonts.changa(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Botón Generar Reporte (sin funcionalidad por ahora)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Generar Reporte',
                        style: GoogleFonts.changa(fontSize: 18, fontWeight: FontWeight.w500),
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
}