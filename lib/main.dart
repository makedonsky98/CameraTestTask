import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
//import 'package:flutter/services.dart';

import 'extensions/context_extension.dart';
import 'services/permission_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CameraTestApp());
}

class CameraTestApp extends StatelessWidget {
  const CameraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(
          seedColor: Colors.blueAccent,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Camera Test'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  bool _hasPermissions = false;
  bool _isLoading = true;
  bool _isRequesting = false;
  String _missingPermissionsText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      if (state == AppLifecycleState.resumed) {
        _updatePermissionStatus();
      }

      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Камеру краще зупиняти/звільняти, коли додаток неактивний,
      // але для простоти поки залишимо dispose при виході.
      // В складніших кейсах тут роблять controller.dispose()
    } else if (state == AppLifecycleState.resumed) {
      _updatePermissionStatus();
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;

    setState(() {
      _isLoading = true;
      _isRequesting = true;
    });

    final hasAccess = await _permissionService.requestSequentialPermissions();
    await _updateMissingDescription();

    if (!mounted) return;

    if (hasAccess) {
      await _initCamera();
    }

    setState(() {
      _hasPermissions = hasAccess;
      _isLoading = false;
      _isRequesting = false;
    });
  }

  Future<void> _updatePermissionStatus() async {
    if (_isRequesting) return;

    final hasAccess = await _permissionService.checkStatusOnly();
    await _updateMissingDescription();

    if (hasAccess && !_isCameraInitialized) {
      await _initCamera();
    }

    if (!mounted) return;

    setState(() {
      _hasPermissions = hasAccess;
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final firstCamera = cameras.first;

      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.ultraHigh,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });

    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  Future<void> _updateMissingDescription() async {
    final missingList = await _permissionService.getMissingPermissionsDescriptions();

    if (missingList.isEmpty) {
      _missingPermissionsText = '';
    } else {
      _missingPermissionsText = missingList.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.inversePrimary,
        centerTitle: true,
        title: Text(
          widget.title,
          style: context.text.titleLarge?.copyWith(
            fontWeight: .w600,
          ),
        ),
      ),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.primary,
        ),
      );
    }

    if (_hasPermissions) {
      if (_isCameraInitialized && _cameraController != null) {
        return SizedBox.expand(
          child: CameraPreview(_cameraController!),
        );
      } else {
        return Center(
          child: CircularProgressIndicator(
            color: context.colors.primary,
          ),
        );
      }
    } else {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: context.colors.error,
              size: 64,
            ),
            Container(
              width: 0.8 * context.width,
              margin: const .only(
                top: 16,
                bottom: 24,
              ),
              child: Text.rich(
                TextSpan(
                  text: 'Для роботи додатку потрібен доступ до: ',
                  style: context.text.bodyLarge,
                  children: [
                    TextSpan(
                      text: _missingPermissionsText,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: .w600,
                      ),
                    ),
                    TextSpan(
                      text: '.',
                      style: context.text.bodyLarge,
                    ),
                  ],
                ),
                textAlign: .center,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _permissionService.openSettings();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Відкрити налаштування'),
            ),
          ],
        ),
      );
    }
  }
}