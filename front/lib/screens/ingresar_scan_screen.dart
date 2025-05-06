import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_screen.dart';
import '../services/face_recognition_service.dart';

class IngresarScanScreen extends StatefulWidget {
  const IngresarScanScreen({Key? key}) : super(key: key);

  @override
  _IngresarScanScreenState createState() => _IngresarScanScreenState();
}

class _IngresarScanScreenState extends State<IngresarScanScreen> {
  CameraController? _cameraController;
  Future<void>? _initControllerFuture;
  bool _acceptedTerms = false; // Controla el pop-up de términos
  bool _isProcessing = false; // Para controlar el estado de procesamiento
  String? _username; // Para guardar el nombre de usuario al registrar

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
      try {
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
      } catch (e) {
        FaceRecognitionService.showResultDialog(context, {
          'success': false,
          'message': 'Error al acceder a la cámara: $e',
        });
      }
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Por favor, habilite el permiso de cámara en la configuración.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere acceso a la cámara para continuar.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // Método para capturar foto y realizar login
  Future<void> _loginWithFace() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        await _requestCameraPermission();
      }

      // Asegurarse de que la cámara esté completamente inicializada
      await _initControllerFuture;

      // Captura la imagen
      final XFile imageFile = await _cameraController!.takePicture();

      // Llama al servicio de reconocimiento facial
      final result = await FaceRecognitionService.login(imageFile);

      if (result['success']) {
        // Login exitoso, pasa el nombre del usuario a WelcomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => WelcomeScreen(username: result['name']),
          ),
        );
      } else {
        // Error en el login
        FaceRecognitionService.showResultDialog(context, result);
      }
    } catch (e) {
      // Error al capturar la imagen o procesar el login
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

  Future<void> _registerNewUser() async {
    if (_isProcessing) return;

    // Muestra un diálogo para ingresar el nombre de usuario
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registrar Nuevo Usuario'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Nombre de Usuario',
              hintText: 'Ingrese su nombre',
            ),
            onChanged: (value) {
              _username = value.trim();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (_username == null || _username!.isEmpty) {
                  FaceRecognitionService.showResultDialog(context, {
                    'success': false,
                    'message':
                        'Por favor, ingrese un nombre de usuario válido.',
                  });
                  return;
                }

                setState(() {
                  _isProcessing = true;
                });

                try {
                  if (_cameraController == null ||
                      !_cameraController!.value.isInitialized) {
                    await _requestCameraPermission();
                  }

                  // Asegurarse de que la cámara esté completamente inicializada
                  await _initControllerFuture;

                  // Captura la imagen
                  final XFile imageFile =
                      await _cameraController!.takePicture();

                  // Llama al servicio de registro
                  final result = await FaceRecognitionService.register(
                    imageFile,
                    _username!,
                  );

                  FaceRecognitionService.showResultDialog(context, result);

                  if (result['success']) {
                    // Redirigir a WelcomeScreen después de un registro exitoso
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => WelcomeScreen(username: _username),
                      ),
                    );
                  }
                } catch (e) {
                  FaceRecognitionService.showResultDialog(context, {
                    'success': false,
                    'message': 'Error al registrar usuario: ${e.toString()}',
                  });
                } finally {
                  setState(() {
                    _isProcessing = false;
                  });
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
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
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // ─── Contenido principal ───
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
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
                              if (snapshot.connectionState ==
                                  ConnectionState.done) {
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
                      'Alinea tu rostro para\npoder escanearte',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Botón Escanear y guardar (Login)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _loginWithFace,
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
                                'Ingresar',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botón Registrar nuevo usuario
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _registerNewUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Registrar nuevo usuario',
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
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // ─── Pop-up Términos y Condiciones ───
            if (!_acceptedTerms) ...[
              // Fondo semi-transparente
              Positioned.fill(
                child: ModalBarrier(color: Colors.black45, dismissible: false),
              ),
              // Diálogo centrado
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El acceso a la cámara no será utilizado con fines malintencionados ni se almacenarán imágenes o videos sin el consentimiento explícito del usuario. '
                        'Toda la información recopilada se usará exclusivamente dentro del contexto de la funcionalidad de reconocimiento facial.',
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
