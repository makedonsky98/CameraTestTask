import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'local_gallery_screen.dart';
import '../extensions/context_extension.dart';
import '../services/permission_service.dart';

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
  File? _overlayImage;
  final ImagePicker _picker = ImagePicker();

  bool _isShootingButtonDown = false;
  bool _showFlashEffect = false;

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

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      cameraController?.dispose();

      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraController = null;
        });
      }
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
    if (hasAccess) await _initCamera();

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

      final newController = CameraController(
        camera,
        ResolutionPreset.ultraHigh,
        enableAudio: true,
      );

      _cameraController = newController;

      await newController.initialize();

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);

    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

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

    setState(() {
      _showFlashEffect = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showFlashEffect = false;
        });
      }
    });

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

  Future<void> _pickOverlayImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _overlayImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking overlay: $e");
    }
  }

  void _removeOverlay() {
    setState(() {
      _overlayImage = null;
    });
  }

  void _openGallery() {
    context.push(
      const LocalGalleryScreen(),
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
    final shootingButtonSize = 72.0;
    final controlPanelHeight = 48.0;
    final controlPanelPaddingBottom = 32.0;
    final controlPanelPaddingHorizontal = 16.0;
    final controlButtonsSize = 32.0;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.primary,
        ),
      );
    }

    if (_hasPermissions) {
      return Stack(
        children: [
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(child: CircularProgressIndicator()),

          if (_overlayImage != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.file(
                  _overlayImage!,
                  fit: .cover,
                ),
              ),
            ),

          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showFlashEffect ? 0.7 : 0.0,
                duration: const Duration(milliseconds: 50),
                child: Container(
                  color: Colors.black,
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Stack(
                children: [
                  Align(
                    alignment: .bottomCenter,
                    child: Container(
                      height: controlPanelHeight,
                      margin: .only(
                        top: 0,
                        bottom: controlPanelPaddingBottom,
                        left: controlPanelPaddingHorizontal,
                        right: controlPanelPaddingHorizontal,
                      ),
                      padding: const .symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: .circular(controlPanelHeight / 2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: _overlayImage == null ? _pickOverlayImage : _removeOverlay,
                                  icon: Icon(
                                    _overlayImage == null ? Icons.layers_outlined : Icons.layers_clear_outlined,
                                    color: Colors.white,
                                    size: controlButtonsSize,
                                  ),
                                ),
                                if (_cameras.length > 1)
                                  IconButton(
                                    onPressed: _switchCamera,
                                    icon: Icon(
                                      Icons.flip_camera_ios,
                                      color: Colors.white,
                                      size: controlButtonsSize,
                                    ),
                                  )
                                else
                                  SizedBox(width: controlButtonsSize),
                              ],
                            ),
                          ),

                          SizedBox(width: shootingButtonSize),

                          Expanded(
                            child: Row(
                              mainAxisAlignment: .spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.video_camera_back,
                                    color: Colors.white,
                                    size: controlButtonsSize,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _openGallery,
                                  child: _lastPhoto == null
                                      ? Icon(Icons.photo_library, color: Colors.white, size: controlButtonsSize)
                                      : Container(
                                    width: controlButtonsSize,
                                    height: controlButtonsSize,
                                    decoration: BoxDecoration(
                                      borderRadius: .circular(8),
                                      image: DecorationImage(
                                        image: ResizeImage(
                                          FileImage(_lastPhoto!),
                                          width: (controlButtonsSize * 3).toInt(),
                                        ),
                                        fit: .cover,
                                      ),
                                      border: .all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Align(
                    alignment: .bottomCenter,
                    child: Padding(
                      padding: .only(
                          bottom: controlPanelPaddingBottom - (shootingButtonSize - controlPanelHeight) / 2,
                      ),
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _isShootingButtonDown = true),
                        onTapUp: (_) => setState(() => _isShootingButtonDown = false),
                        onTapCancel: () => setState(() => _isShootingButtonDown = false),
                        onTap: _takePicture,
                        child: AnimatedScale(
                          scale: _isShootingButtonDown ? 0.95 : 1.0,
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeInOut,
                          child: Container(
                            width: shootingButtonSize,
                            height: shootingButtonSize,
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: context.colors.error,
                              border: .all(color: context.colors.onError, width: 3),
                            ),
                            child: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    else {
      return SizedBox(
        width: .infinity,
        height: .infinity,
        child: Column(
          mainAxisAlignment: .center,
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
                        fontWeight: .bold,
                        color: context.colors.error,
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