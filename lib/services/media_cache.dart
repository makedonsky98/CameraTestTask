import 'dart:io';
import 'dart:typed_data';

import 'package:video_thumbnail/video_thumbnail.dart';

class _CacheEntry {
  final Uint8List data;
  final DateTime timestamp;
  _CacheEntry({required this.data, required this.timestamp});
}

class MediaCache {
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(hours: 1);

  static Uint8List? get(String path) {
    final entry = _cache[path];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _ttl) {
      _cache.remove(path);
      return null;
    }
    return entry.data;
  }

  static Future<Uint8List?> getOrGenerate(File file) async {
    final cached = get(file.path);
    if (cached != null) return cached;

    final uint8list = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 200,
      quality: 50,
    );

    if (uint8list != null) {
      _cache[file.path] = _CacheEntry(
        data: uint8list,
        timestamp: DateTime.now(),
      );
    }
    return uint8list;
  }
}


Future<List<String>> isolateLoadMedia(String directoryPath) async {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) return [];

  final List<FileSystemEntity> entities = dir.listSync();

  final mediaFiles = entities
      .whereType<File>()
      .where((file) {
    final path = file.path.toLowerCase();
    return path.endsWith('.jpg') || path.endsWith('.mp4');
  })
      .toList();

  final Map<String, DateTime> fileDates = {};

  for (var file in mediaFiles) {
    final stat = file.statSync();
    fileDates[file.path] = stat.modified;
  }

  mediaFiles.sort((a, b) {
    final dateA = fileDates[a.path] ?? DateTime(1970);
    final dateB = fileDates[b.path] ?? DateTime(1970);
    return dateB.compareTo(dateA);
  });

  return mediaFiles.map((e) => e.path).toList();
}