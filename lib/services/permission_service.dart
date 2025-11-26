import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  Future<bool> requestSequentialPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) return false;

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) return false;

    return await _requestStoragePermission();
  }

  Future<List<String>> getMissingPermissionsDescriptions() async {
    List<String> missing = [];

    if (!(await Permission.camera.status.isGranted)) {
      missing.add("Камери");
    }

    if (!(await Permission.microphone.status.isGranted)) {
      missing.add("Мікрофону");
    }

    if (Platform.isIOS) {
      if (!(await Permission.photos.status.isGranted)) {
        missing.add("Галереї");
      }
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        bool photos = await Permission.photos.status.isGranted;
        bool videos = await Permission.videos.status.isGranted;

        if (!photos && !videos) {
          missing.add("Фото та Відео");
        } else {
          if (!photos) missing.add("Фото");
          if (!videos) missing.add("Відео");
        }
      } else {
        if (!(await Permission.storage.status.isGranted)) {
          missing.add("Сховища");
        }
      }
    }

    return missing;
  }

  Future<bool> checkStatusOnly() async {
    var cameraStatus = await Permission.camera.status;
    var micStatus = await Permission.microphone.status;
    var storageStatus = await _checkStorageStatusOnly();

    return cameraStatus.isGranted && micStatus.isGranted && storageStatus;
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) {
      return await Permission.photos.request().isGranted;
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        return statuses[Permission.photos] == PermissionStatus.granted &&
            statuses[Permission.videos] == PermissionStatus.granted;
      } else {
        return await Permission.storage.request().isGranted;
      }
    }

    return false;
  }

  Future<bool> _checkStorageStatusOnly() async {
    if (Platform.isIOS) {
      return await Permission.photos.status.isGranted;
    } else if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        var photos = await Permission.photos.status;
        var videos = await Permission.videos.status;

        return photos.isGranted && videos.isGranted;
      } else {
        return await Permission.storage.status.isGranted;
      }
    }

    return false;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}