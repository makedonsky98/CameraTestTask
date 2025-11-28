import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../extensions/context_extension.dart';
import '../services/media_cache.dart';
import 'media_view_screen.dart';

class LocalGalleryScreen extends StatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  State<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends State<LocalGalleryScreen> {
  List<File> _mediaFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final appDir = await getApplicationDocumentsDirectory();

    final List<String> sortedPaths = await compute(isolateLoadMedia, appDir.path);
    final List<File> files = sortedPaths.map((path) => File(path)).toList();

    if (mounted) {
      setState(() {
        _mediaFiles = files;
        _isLoading = false;
      });
    }
  }

  void _openFullScreen(BuildContext context, int index) async {
    final bool? shouldReload = await context.push(
      MediaViewScreen(
        images: _mediaFiles,
        initialIndex: index,
      ),
    );

    if (shouldReload == true) {
      _loadMedia();
    }
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
          ? const Center(child: Text("Немає контенту"))
          : RawScrollbar(
        thumbVisibility: false,
        thumbColor: context.colors.inversePrimary.withValues(alpha: 0.7),
        radius: const Radius.circular(8),
        child: GridView.builder(
          cacheExtent: 1000,
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
              : const SizedBox(),
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
    final cachedBytes = MediaCache.get(file.path);

    if (cachedBytes != null) {
      return _buildVideoContent(cachedBytes);
    }

    return FutureBuilder<Uint8List?>(
      future: MediaCache.getOrGenerate(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return _buildVideoContent(snapshot.data!);
        } else {
          return Container(color: Colors.grey[300]);
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