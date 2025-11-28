import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart' hide ImageFormat;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'local_gallery_screen.dart';
import '../extensions/context_extension.dart';
import '../services/permission_service.dart';
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.title
  });

  final String title;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();
  final CameraService _cameraService = CameraService();

  bool _isCameraInitialized = false;
  bool _hasPermissions = false;
  bool _isLoading = true;
  bool _isRequesting = false;

  String _loadingText = 'Запуск камери...';
  bool _isNavigationInProgress = false;

  String _missingPermissionsText = '';

  File? _lastPhoto;
  Uint8List? _lastVideoThumbnail;

  File? _overlayImage;
  final ImagePicker _picker = ImagePicker();

  bool _isShootingButtonDown = false;
  bool _showFlashEffect = false;

  Timer? _videoTimer;
  int _recordDuration = 0;
  bool _isRedDotVisible = true;

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
    _stopTimer();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_isNavigationInProgress) {
      _stopTimer();
      _cameraService.dispose().then((_) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _updatePermissionStatus();

      if (!_isCameraInitialized && _hasPermissions) {
        _initCamera();
      }
    }
  }

  void _startTimer() {
    _videoTimer?.cancel();
    _videoTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _isRedDotVisible = !_isRedDotVisible;
          if (!_cameraService.isRecordingPaused && timer.tick % 2 == 0) {
            _recordDuration++;
          }
        });
      }
    });
  }

  void _stopTimer() {
    _videoTimer?.cancel();
    _videoTimer = null;
    _recordDuration = 0;
    _isRedDotVisible = true;
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _updateLastMediaPreview(File file) async {
    final isVideo = file.path.endsWith('.mp4');

    if (isVideo) {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );

      if (mounted) {
        setState(() {
          _lastPhoto = file;
          _lastVideoThumbnail = uint8list;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _lastPhoto = file;
          _lastVideoThumbnail = null;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;

    setState(() {
      _isLoading = true;
      _isRequesting = true;
      _loadingText = 'Перевірка дозволів...';
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

    if (!mounted) return;
    setState(() => _hasPermissions = hasAccess);
  }

  Future<void> _updateMissingDescription() async {
    final missingList = await _permissionService.getMissingPermissionsDescriptions();
    _missingPermissionsText = missingList.isEmpty ? '' : missingList.join(', ');
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingText = 'Запуск камери...';
    });

    try {
      await _cameraService.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameraService.cameraCount < 2) return;

    setState(() {
      _isCameraInitialized = false;
      _isLoading = true;
      _loadingText = 'Перемикання камери...';
    });

    await _cameraService.switchCamera();

    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
      _isLoading = false;
    });
  }

  Future<void> _takePicture() async {
    if (!_cameraService.isInitialized) return;

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

    final File? photo = await _cameraService.takePicture();

    if (photo != null && mounted) {
      await _updateLastMediaPreview(photo);
    }
  }

  Future<void> _loadLastPhoto() async {
    final dir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entities = dir.listSync();

    final files = entities.whereType<File>().where((file) {
      return file.path.endsWith('.jpg') || file.path.endsWith('.mp4');
    }).toList();

    if (files.isNotEmpty) {
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      await _updateLastMediaPreview(files.first);
    }
  }

  Future<void> _pickOverlayImage() async {
    _isNavigationInProgress = true;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _overlayImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking overlay: $e");
    } finally {
      _isNavigationInProgress = false;
    }
  }

  void _removeOverlay() {
    setState(() => _overlayImage = null);
  }

  void _openGallery() {
    _isNavigationInProgress = true;

    context.push(
      const LocalGalleryScreen(),
    ).then((_) {
      _isNavigationInProgress = false;
      _loadLastPhoto();
    });
  }

  Future<void> _startVideoRecording() async {
    if (!_cameraService.isInitialized) return;
    if (_cameraService.isRecordingVideo) return;

    _recordDuration = 0;
    _startTimer();

    await _cameraService.startVideoRecording();

    if (mounted) setState(() {});
  }

  Future<void> _stopVideoRecording() async {
    if (!_cameraService.isRecordingVideo) return;

    _stopTimer();

    final File? videoFile = await _cameraService.stopVideoRecording();

    if (mounted && videoFile != null) {
      await _updateLastMediaPreview(videoFile);
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePauseVideo() async {
    if (!_cameraService.isRecordingVideo) return;

    if (_cameraService.isRecordingPaused) {
      await _cameraService.resumeVideoRecording();
    } else {
      await _cameraService.pauseVideoRecording();
    }

    if (mounted) setState(() {});
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

    if (!_hasPermissions && !_isRequesting) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: context.colors.error, size: 64),
            Container(
              width: 0.8 * context.width,
              margin: const EdgeInsets.only(top: 16, bottom: 24),
              child: Text.rich(
                TextSpan(
                  text: 'Для роботи додатку потрібен доступ до: ',
                  style: context.text.bodyLarge,
                  children: [
                    TextSpan(
                      text: _missingPermissionsText,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.error,
                      ),
                    ),
                    TextSpan(text: '.', style: context.text.bodyLarge),
                  ],
                ),
                textAlign: TextAlign.center,
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

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _isCameraInitialized && _cameraService.controller != null && !_isLoading
                ? SizedBox.expand(
              key: ValueKey(_cameraService.controller!.description.lensDirection),
              child: CameraPreview(_cameraService.controller!),
            )
                : Container(
              key: const ValueKey('loading'),
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: context.colors.primary),
                    const SizedBox(height: 16),
                    Text(
                      _loadingText,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_overlayImage != null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.file(
                _overlayImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showFlashEffect ? 0.7 : 0.0,
              duration: const Duration(milliseconds: 50),
              child: Container(color: Colors.black),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: controlPanelHeight,
                    margin: EdgeInsets.only(
                      top: 0,
                      bottom: controlPanelPaddingBottom,
                      left: controlPanelPaddingHorizontal,
                      right: controlPanelPaddingHorizontal,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(controlPanelHeight / 2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_cameraService.isRecordingVideo)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (_isRedDotVisible && !_cameraService.isRecordingPaused)
                                            ? Colors.red
                                            : Colors.transparent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(_recordDuration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFeatures: [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                )
                              else if (_cameraService.cameraCount > 1)
                                IconButton(
                                  onPressed: _isLoading ? null : _switchCamera,
                                  icon: Icon(
                                    Icons.flip_camera_ios,
                                    color: _isLoading ? Colors.white54 : Colors.white,
                                    size: controlButtonsSize,
                                  ),
                                )
                              else
                                SizedBox(width: controlButtonsSize),

                              if (!_cameraService.isRecordingVideo || _overlayImage != null)
                                IconButton(
                                  onPressed: _isLoading ? null : (_overlayImage == null ? _pickOverlayImage : _removeOverlay),
                                  icon: Icon(
                                    _overlayImage == null ? Icons.layers_outlined : Icons.layers_clear_outlined,
                                    color: _isLoading ? Colors.white54 : Colors.white,
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
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_cameraService.isRecordingVideo) ...[
                                IconButton(
                                  onPressed: _stopVideoRecording,
                                  icon: Icon(
                                    Icons.stop_rounded,
                                    color: Colors.white,
                                    size: controlButtonsSize,
                                  ),
                                ),

                                GestureDetector(
                                  onTap: null,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: _buildGalleryIcon(controlButtonsSize),
                                  ),
                                ),
                              ] else ...[
                                IconButton(
                                  onPressed: _isLoading ? null : _startVideoRecording,
                                  icon: Icon(
                                    Icons.videocam,
                                    color: _isLoading ? Colors.white54 : Colors.white,
                                    size: controlButtonsSize,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isLoading ? null : _openGallery,
                                  child: Opacity(
                                    opacity: _isLoading ? 0.5 : 1.0,
                                    child: _buildGalleryIcon(controlButtonsSize),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: controlPanelPaddingBottom - (shootingButtonSize - controlPanelHeight) / 2,
                    ),
                    child: GestureDetector(
                      onTapDown: (_) {
                        if (!_cameraService.isRecordingVideo && !_isLoading) {
                          setState(() => _isShootingButtonDown = true);
                        }
                      },
                      onTapUp: (_) {
                        if (!_cameraService.isRecordingVideo && !_isLoading) {
                          setState(() => _isShootingButtonDown = false);
                        }
                      },
                      onTapCancel: () {
                        if (!_cameraService.isRecordingVideo && !_isLoading) {
                          setState(() => _isShootingButtonDown = false);
                        }
                      },
                      onTap: _isLoading
                          ? null
                          : (_cameraService.isRecordingVideo ? _togglePauseVideo : _takePicture),

                      child: AnimatedScale(
                        scale: _isShootingButtonDown ? 0.95 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: shootingButtonSize,
                          height: shootingButtonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _cameraService.isRecordingVideo
                                ? Colors.white
                                : (_isLoading ? Colors.grey : context.colors.error),
                            border: Border.all(
                                color: _cameraService.isRecordingVideo
                                    ? Colors.white
                                    : (_isLoading ? Colors.grey : context.colors.onError),
                                width: 3
                            ),
                          ),
                          child: Center(
                            child: _cameraService.isRecordingVideo
                                ? Icon(
                              _cameraService.isRecordingPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded,
                              color: Colors.black,
                              size: shootingButtonSize / 2,
                            )
                                : null,
                          ),
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

  Widget _buildGalleryIcon(double size) {
    if (_lastPhoto == null) {
      return Icon(Icons.photo_library, color: Colors.white, size: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        image: DecorationImage(
          image: _lastVideoThumbnail != null
              ? MemoryImage(_lastVideoThumbnail!) as ImageProvider
              : ResizeImage(
            FileImage(_lastPhoto!),
            width: (size * 3).toInt(),
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: _lastVideoThumbnail != null
          ? const Center(
        child: Icon(Icons.play_arrow_rounded,
            color: Colors.white70, size: 20),
      )
          : null,
    );
  }
}