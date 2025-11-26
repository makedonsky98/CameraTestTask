import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'extensions/context_extension.dart';
import 'services/permission_service.dart';
import 'pages/local_gallery_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Camera Test'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  CameraController? _cameraController;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isCameraInitialized = false;
  bool _hasPermissions = false;
  bool _isLoading = true;
  bool _isRequesting = false;
  String _missingPermissionsText = '';

  File? _lastPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _loadLastPhoto();
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
      if (state == AppLifecycleState.resumed) _updatePermissionStatus();
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;
    setState(() { _isLoading = true; _isRequesting = true; });
    final hasAccess = await _permissionService.requestSequentialPermissions();
    await _updateMissingDescription();
    if (!mounted) return;
    if (hasAccess) await _initCamera();
    setState(() { _hasPermissions = hasAccess; _isLoading = false; _isRequesting = false; });
  }

  Future<void> _updatePermissionStatus() async {
    if (_isRequesting) return;
    final hasAccess = await _permissionService.checkStatusOnly();
    await _updateMissingDescription();
    if (hasAccess && !_isCameraInitialized) await _initCamera();
    if (!mounted) return;
    setState(() => _hasPermissions = hasAccess);
  }

  Future<void> _updateMissingDescription() async {
    final missingList = await _permissionService.getMissingPermissionsDescriptions();
    _missingPermissionsText = missingList.isEmpty ? '' : missingList.join(', ');
  }

  Future<void> _initCamera() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }

      if (_cameras.isEmpty) return;

      if (_cameraController != null) {
        await _cameraController!.dispose();
      }

      final camera = _cameras[_selectedCameraIndex];

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  // --- ЛОГІКА ПЕРЕМИКАННЯ КАМЕР ---
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isCameraInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });

    await _initCamera();
  }

  Future<void> _loadLastPhoto() async {
    final dir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entities = dir.listSync();

    final files = entities.whereType<File>().where((file) {
      return file.path.endsWith('.jpg');
    }).toList();

    if (files.isNotEmpty) {
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      setState(() {
        _lastPhoto = files.first;
      });
    }
  }

  Future<void> _takePicture() async {
    final CameraController? cameraController = _cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) return;
    if (cameraController.value.isTakingPicture) return;

    try {
      final XFile image = await cameraController.takePicture();
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().toIso8601String().replaceAll(':', '-')}.jpg';
      final String newPath = path.join(appDir.path, fileName);

      await image.saveTo(newPath);

      setState(() {
        _lastPhoto = File(newPath);
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  void _openGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LocalGalleryScreen(),
      ),
    ).then((_) => _loadLastPhoto());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.inversePrimary,
        centerTitle: true,
        title: Text(widget.title),
      ),
      body: _buildBodyContent(context),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.colors.primary));
    }

    if (!_hasPermissions) {
      return Center(child: Text("Немає дозволів: $_missingPermissionsText"));
    }

    return Stack(
      children: [
        if (_isCameraInitialized && _cameraController != null)
          SizedBox.expand(
            child: CameraPreview(_cameraController!),
          )
        else
          const Center(child: CircularProgressIndicator()),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: _openGallery,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      image: _lastPhoto != null
                          ? DecorationImage(
                        image: FileImage(_lastPhoto!),
                        fit: BoxFit.cover,
                      )
                          : null,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: _lastPhoto == null
                        ? const Icon(Icons.photo_library, color: Colors.white)
                        : null,
                  ),
                ),

                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.grey, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width: 50,
                  height: 50,
                  child: _cameras.length > 1
                      ? IconButton(
                    onPressed: _switchCamera,
                    icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 30
                    ),
                  )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}