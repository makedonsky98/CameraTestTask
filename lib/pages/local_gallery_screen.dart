import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../extensions/context_extension.dart';
import 'media_view_screen.dart';

class _CacheEntry {
  final Uint8List data;
  final DateTime timestamp;

  _CacheEntry({
    required this.data,
    required this.timestamp
  });
}

Future<List<String>> _isolateLoadMedia(String directoryPath) async {
  final dir = Directory(directoryPath);
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

class LocalGalleryScreen extends StatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  State<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends State<LocalGalleryScreen> {
  List<File> _mediaFiles = [];
  bool _isLoading = true;

  static final Map<String, _CacheEntry> _thumbnailCache = {};
  static const Duration _cacheTtl = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final appDir = await getApplicationDocumentsDirectory();
    final List<String> sortedPaths = await compute(_isolateLoadMedia, appDir.path);
    final List<File> files = sortedPaths.map((path) => File(path)).toList();

    if (mounted) {
      setState(() {
        _mediaFiles = files;
        _isLoading = false;
      });
    }
  }

  void _openFullScreen(BuildContext context, int index) async {
    await context.push(
      MediaViewScreen(
        images: _mediaFiles,
        initialIndex: index,
      ),
    );

    _loadMedia();
  }

  Future<Uint8List?> _generateThumbnail(File file) async {
    final now = DateTime.now();

    if (_thumbnailCache.containsKey(file.path)) {
      final entry = _thumbnailCache[file.path]!;
      if (now.difference(entry.timestamp) < _cacheTtl) {
        return entry.data;
      } else {
        _thumbnailCache.remove(file.path);
      }
    }

    final uint8list = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 200,
      quality: 50,
    );

    if (uint8list != null) {
      _thumbnailCache[file.path] = _CacheEntry(
          data: uint8list,
          timestamp: now
      );
    }

    return uint8list;
  }

  @override
  Widget build(BuildContext context) {
    final int thumbWidth = (context.width / 3 * 2).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Галерея"),
        backgroundColor: context.colors.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaFiles.isEmpty
          ? Center(child: Text("Немає контенту", style: context.text.bodyLarge))
          : RawScrollbar(
        thumbVisibility: false,
        thumbColor: context.colors.inversePrimary.withValues(alpha: 0.7),
        radius: const Radius.circular(8),
        child: GridView.builder(
          cacheExtent: 500,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: _mediaFiles.length,
          itemBuilder: (context, index) {
            final file = _mediaFiles[index];
            final isVideo = file.path.toLowerCase().endsWith('.mp4');

            return GestureDetector(
              onTap: () => _openFullScreen(context, index),
              child: Hero(
                tag: file.path,
                child: Container(
                  color: Colors.grey[200],
                  child: isVideo
                      ? _buildVideoTile(file)
                      : _buildImageTile(file, thumbWidth),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageTile(File file, int cacheWidth) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: frame != null
              ? child
              : const Center(child: SizedBox()),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  Widget _buildVideoTile(File file) {
    final cachedEntry = _thumbnailCache[file.path];

    if (cachedEntry != null) {
      final isExpired = DateTime.now().difference(cachedEntry.timestamp) >= _cacheTtl;
      if (!isExpired) {
        return _buildVideoContent(cachedEntry.data);
      }
    }

    return FutureBuilder<Uint8List?>(
      future: _generateThumbnail(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return _buildVideoContent(snapshot.data!);
        } else {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildVideoContent(Uint8List bytes) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: ResizeImage(
            MemoryImage(bytes),
            width: 200,
          ),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        Container(
          color: Colors.black26,
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ],
    );
  }
}