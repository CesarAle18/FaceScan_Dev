import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_scan_screen.dart';
import 'ingresar_scan_screen.dart';

class FaceScanScreen extends StatelessWidget {
  const FaceScanScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    // Aumentamos el logo: 50% del ancho en portrait, 50% de la altura en landscape
    final imageSize = isPortrait ? size.width * 0.5 : size.height * 0.5;
    final verticalSpace = isPortrait ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo ampliado
                      Image.asset(
                        'assets/face_scan_bg0A192F_tolerant.png',
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.contain,
                      ),

                      SizedBox(height: verticalSpace),

                      // Subtítulo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Escanea tu rostro para ingresar o regístrate si eres un nuevo usuario.',
                          style: GoogleFonts.changa(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: verticalSpace * 2),

                      // Botones
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: isPortrait
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _buildButton(
                                      context,
                                      label: 'Ingresar',
                                      onTap: () {
                                        Navigator.pushNamed(context, '/ingresar');
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildButton(
                                      context,
                                      label: 'Registrarse',
                                      onTap: () {
                                        Navigator.pushNamed(context, '/register');
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildButton(
                                    context,
                                    label: 'Ingresar',
                                    onTap: () {
                                      Navigator.pushNamed(context, '/ingresar');
                                    },
                                  ),
                                  SizedBox(height: verticalSpace),
                                  _buildButton(
                                    context,
                                    label: 'Registrarse',
                                    onTap: () {
                                      Navigator.pushNamed(context, '/register');
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context,
      {required String label, required VoidCallback onTap, Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFF147DFE),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.changa(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}