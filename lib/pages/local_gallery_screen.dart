import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../extensions/context_extension.dart';
import 'photo_view_screen.dart';

class LocalGalleryScreen extends StatefulWidget {
  const LocalGalleryScreen({super.key});

  @override
  State<LocalGalleryScreen> createState() => _LocalGalleryScreenState();
}

class _LocalGalleryScreenState extends State<LocalGalleryScreen> {
  List<File> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    final appDir = await getApplicationDocumentsDirectory();

    final List<FileSystemEntity> entities = appDir.listSync();

    final imageFiles = entities
        .whereType<File>()
        .where((file) => file.path.endsWith('.jpg'))
        .toList();

    final Map<String, DateTime> fileDates = {};

    await Future.wait(imageFiles.map((file) async {
      final stat = await file.stat();
      fileDates[file.path] = stat.modified;
    }));

    imageFiles.sort((a, b) {
      final dateA = fileDates[a.path] ?? DateTime(1970);
      final dateB = fileDates[b.path] ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _images = imageFiles;
        _isLoading = false;
      });
    }
  }

  void _openFullScreen(BuildContext context, int index) async {
    await context.push(
      PhotoViewScreen(
        images: _images,
        initialIndex: index,
      ),
    );

    _loadImages();
  }

  @override
  Widget build(BuildContext context) {
    final int thumbWidth = (context.width / 3 * 2).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Мої фото"),
        backgroundColor: context.colors.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? const Center(child: Text("Немає контенту"))
          : RawScrollbar(
        thumbVisibility: false,
        thumbColor: Colors.grey.withValues(alpha: 0.75),
        radius: const .circular(8),

        fadeDuration: const Duration(milliseconds: 300),
        timeToFade: const Duration(seconds: 1),

        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemCount: _images.length,
          itemBuilder: (context, index) {
            final file = _images[index];
            return GestureDetector(
              onTap: () => _openFullScreen(context, index),
              child: Hero(
                tag: file.path,
                child: Container(
                  color: Colors.grey[200],
                  child: Image.file(
                    file,
                    fit: .cover,
                    width: .infinity,
                    height: .infinity,
                    cacheWidth: thumbWidth,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: frame != null
                            ? child
                            : const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}