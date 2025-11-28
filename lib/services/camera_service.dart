import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  int get cameraCount => _cameras.length;

  Future<void> initialize() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
        _selectedCameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back
        );
        if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;
      }

      if (_cameras.isEmpty) return;

      if (_controller != null && _controller!.description == _cameras[_selectedCameraIndex]) {
        return;
      }

      await dispose();

      final camera = _cameras[_selectedCameraIndex];
      _controller = CameraController(
        camera,
        ResolutionPreset.ultraHigh,
        enableAudio: true,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
    } catch (e) {
      debugPrint("CameraService init error: $e");
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentCamera = _cameras[_selectedCameraIndex];
    final currentDirection = currentCamera.lensDirection;

    CameraLensDirection targetDirection;

    if (currentDirection == CameraLensDirection.back) {
      targetDirection = CameraLensDirection.front;
    } else {
      targetDirection = CameraLensDirection.back;
    }

    int newIndex = _cameras.indexWhere((c) => c.lensDirection == targetDirection);

    if (newIndex != -1) {
      _selectedCameraIndex = newIndex;
    } else {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    }

    await initialize();
  }

  Future<File?> takePicture() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile image = await cameraController.takePicture();

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().toIso8601String().replaceAll(':', '-')}.jpg';
      final String newPath = path.join(appDir.path, fileName);
      await image.saveTo(newPath);

      return File(newPath);
    } catch (e) {
      debugPrint("CameraService takePicture error: $e");
      return null;
    }
  }
}