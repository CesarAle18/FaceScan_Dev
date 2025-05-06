import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/face_recognition_service.dart';
import 'welcome_screen.dart';

class RegisterScanScreen extends StatefulWidget {
  const RegisterScanScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScanScreen> createState() => _RegisterScanScreenState();
}

class _RegisterScanScreenState extends State<RegisterScanScreen> {
  CameraController? _cameraController;
  Future<void>? _initControllerFuture;
  bool _acceptedTerms = false;
  bool _isProcessing = false; // Para controlar el estado de procesamiento
  String _username = ''; // Para guardar el nombre de usuario

  // Controller para el campo de texto
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTermsAcceptance(); // Cargar el estado de aceptación de términos
    _requestCameraPermission();
  }

  // Cargar el estado de aceptación de términos desde SharedPreferences
  Future<void> _loadTermsAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _acceptedTerms = prefs.getBool('acceptedTerms') ?? false;
    });
  }

  // Guardar el estado de aceptación de términos
  Future<void> _saveTermsAcceptance(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('acceptedTerms', accepted);
    setState(() {
      _acceptedTerms = accepted;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initControllerFuture = _cameraController!.initialize();
      setState(() {});
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      FaceRecognitionService.showResultDialog(context, {
        'success': false,
        'message': 'Se requiere acceso a la cámara para continuar.',
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Método para registrar usuario
  Future<void> _registerUser() async {
    if (_isProcessing) return;

    // Validar que se haya ingresado un nombre de usuario
    if (_username.trim().isEmpty) {
      FaceRecognitionService.showResultDialog(context, {
        'success': false,
        'message': 'Por favor, ingresa un nombre de usuario válido.',
      });
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        // Captura la imagen
        final XFile imageFile = await _cameraController!.takePicture();

        // Llama al servicio de registro
        final result = await FaceRecognitionService.register(imageFile, _username.trim());

        // Mostrar el resultado
        if (result['success']) {
          // Registro exitoso, navegar a la pantalla de bienvenida
          FaceRecognitionService.showResultDialog(context, result);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => WelcomeScreen(username: _username.trim()),
            ),
          );
        } else {
          // Error en el registro
          FaceRecognitionService.showResultDialog(context, result);
        }
      } else {
        throw Exception('La cámara no está inicializada.');
      }
    } catch (e) {
      // Error al capturar la imagen o procesar el registro
      FaceRecognitionService.showResultDialog(context, {
        'success': false,
        'message': 'Error al procesar la imagen: ${e.toString()}',
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
    final previewSize = isPortrait ? size.width * 0.8 : size.height * 0.6;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: const Text('Registro de Usuario', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  // Campo para ingresar nombre de usuario
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario',
                        hintText: 'Ingrese su nombre',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white54),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.lightBlue),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) {
                        setState(() {
                          _username = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preview de cámara ampliado
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

                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Alinea tu rostro para\ncompletar tu registro',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Botón Registrar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF147DFE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                            : const Text(
                                'Registrar Usuario',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Botón Cancelar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // ─── Pop-up Términos y Condiciones ───
            if (!_acceptedTerms) ...[
              Positioned.fill(
                child: ModalBarrier(color: Colors.black45, dismissible: false),
              ),
              Center(
                child: Container(
                  width: size.width * 0.8,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Términos y condiciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El acceso a la cámara no será utilizado con fines malintencionados ni se almacenarán imágenes o videos sin el consentimiento explícito del usuario. '
                        'Toda la información recopilada se usará exclusivamente dentro del contexto de la funcionalidad del reconocimiento facial.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (v) {
                              if (v != null) {
                                _saveTermsAcceptance(v);
                              }
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Acepto términos y condiciones',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}