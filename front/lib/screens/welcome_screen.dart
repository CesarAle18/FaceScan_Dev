import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_recognition_service.dart';

class WelcomeScreen extends StatefulWidget {
  final String? username;

  const WelcomeScreen({Key? key, this.username}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  CameraController? _cameraController;
  Future<void>? _initControllerFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        FaceRecognitionService.showResultDialog(context, {
          'success': false,
          'message': 'No se encontraron cámaras disponibles.',
        });
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initControllerFuture = _cameraController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        FaceRecognitionService.showResultDialog(context, {
          'success': false,
          'message': 'Error al inicializar la cámara: $e',
        });
      });
    } else {
      FaceRecognitionService.showResultDialog(context, {
        'success': false,
        'message': 'Permiso de cámara denegado. Por favor, habilite los permisos en la configuración.',
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        await _initializeCamera();
      }

      // Asegurarse de que la cámara esté completamente inicializada
      await _initControllerFuture;

      // Captura la imagen
      final XFile imageFile = await _cameraController!.takePicture();

      // Llama al servicio de logout
      final result = await FaceRecognitionService.logout(imageFile);

      if (result['success']) {
        // Logout exitoso, regresar a la pantalla inicial
        Navigator.pushNamedAndRemoveUntil(context, '/face_scan', (route) => false);
      } else {
        FaceRecognitionService.showResultDialog(context, result);
      }
    } catch (e) {
      FaceRecognitionService.showResultDialog(context, {
        'success': false,
        'message': 'Error al cerrar sesión: ${e.toString()}',
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    final previewSize = isPortrait ? size.width * 0.5 : size.height * 0.4;

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

                // Preview de cámara para logout
                Container(
                  width: previewSize,
                  height: previewSize,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _cameraController == null
                      ? const Icon(
                          Icons.camera_alt,
                          color: Colors.white54,
                          size: 64,
                        )
                      : FutureBuilder<void>(
                          future: _initControllerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CameraPreview(_cameraController!),
                              );
                            } else if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Error al inicializar la cámara',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              );
                            } else {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white54,
                                ),
                              );
                            }
                          },
                        ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Alinea tu rostro para cerrar sesión',
                  style: GoogleFonts.changa(
                    color: Colors.white70,
                    fontSize: 16,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}