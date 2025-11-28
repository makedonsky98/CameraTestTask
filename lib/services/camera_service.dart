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
  bool get isRecordingVideo => _controller?.value.isRecordingVideo ?? false;
  bool get isRecordingPaused => _controller?.value.isRecordingPaused ?? false;
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
      await _controller!.prepareForVideoRecording();

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
    if (isRecordingVideo) return;

    if (_cameras.length < 2) return;

    final currentCamera = _cameras[_selectedCameraIndex];
    final currentDirection = currentCamera.lensDirection;

    CameraLensDirection targetDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front : CameraLensDirection.back;

    int newIndex = _cameras.indexWhere(
        (c) => c.lensDirection == targetDirection
    );

    if (newIndex != -1) {
      _selectedCameraIndex = newIndex;
    } else {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    }

    await initialize();
  }

  Future<File?> takePicture() async {
    if (isRecordingVideo) return null;

    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return null;
    }

    if (cameraController.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile image = await cameraController.takePicture();
      return await _saveFileToDocuments(image, 'jpg');
    } catch (e) {
      debugPrint("CameraService takePicture error: $e");
      return null;
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } catch (e) {
      debugPrint("CameraService startVideoRecording error: $e");
    }
  }

  Future<File?> stopVideoRecording() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      final XFile video = await cameraController.stopVideoRecording();
      return await _saveFileToDocuments(video, 'mp4');
    } catch (e) {
      debugPrint("CameraService stopVideoRecording error: $e");
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.pauseVideoRecording();
    } catch (e) {
      debugPrint("CameraService pauseVideoRecording error: $e");
    }
  }

  Future<void> resumeVideoRecording() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.resumeVideoRecording();
    } catch (e) {
      debugPrint("CameraService resumeVideoRecording error: $e");
    }
  }

  Future<File> _saveFileToDocuments(XFile file, String extension) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = '${DateTime.now().toIso8601String().replaceAll(':', '-')}.$extension';
    final String newPath = path.join(appDir.path, fileName);

    await file.saveTo(newPath);
    return File(newPath);
  }
}