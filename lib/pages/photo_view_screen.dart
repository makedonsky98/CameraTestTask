import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../extensions/context_extension.dart';
import '../widgets/zoomable_image.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<File> _currentImages;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _currentImages = List.from(widget.images);
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return "$bytes B";
    } else if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    } else {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
  }

  String _formatDate(DateTime date) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} "
        "${twoDigits(date.hour)}:${twoDigits(date.minute)}";
  }

  Future<void> _showImageProperties() async {
    try {
      final file = _currentImages[_currentIndex];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final stat = await file.stat();
      final sizeString = _formatFileSize(stat.size);
      final dateString = _formatDate(stat.modified);

      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final resolutionString = "${descriptor.width} x ${descriptor.height}";

      descriptor.dispose();
      buffer.dispose();

      if (!mounted) return;
      context.pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Властивості",
            textAlign: .center,
            style: TextStyle(fontWeight: .w500),
          ),
          content: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              _buildPropertyRow(Icons.image_aspect_ratio, "Розмір:", resolutionString),
              const SizedBox(height: 12),
              _buildPropertyRow(Icons.data_usage, "Вага:", sizeString),
              const SizedBox(height: 12),
              _buildPropertyRow(Icons.calendar_today, "Дата:", dateString),
              const SizedBox(height: 12),
              _buildPropertyRow(Icons.folder_open, "Шлях:", file.path.split('/').last),
            ],
          ),
          actionsAlignment: .center,
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                elevation: 0,
                padding: const .symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("ОК"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted && context.canPop()) context.pop();
      debugPrint("Помилка отримання властивостей: $e");
    }
  }

  Widget _buildPropertyRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: .w500,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deletePhoto() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Видалити фото?",
          textAlign: .center,
          style: TextStyle(fontWeight: .w500),
        ),
        content: const Text(
          "Цю дію не можна скасувати.",
          textAlign: .center,
        ),
        actionsAlignment: .center,
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Скасувати"),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onError,
              elevation: 0,
              padding: const .symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Видалити"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final fileToDelete = _currentImages[_currentIndex];

      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
      }

      setState(() {
        _currentImages.removeAt(_currentIndex);

        if (_currentIndex >= _currentImages.length) {
          _currentIndex = _currentImages.length - 1;
        }
      });

      if (_currentImages.isEmpty) {
        if (mounted) context.pop();
      }
    } catch (e) {
      debugPrint("Помилка видалення: $e");

      if (mounted) {
        context.showErrorSnackBar("Помилка: $e");
      }
    }
  }

  /// Логіка універсального шерингу
  Future<void> _shareContent({
    required XFile file,
    String? text,
    String? subject,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: text,
        subject: subject,
      ),
    );

    switch (result.status) {
      case ShareResultStatus.success:
        debugPrint('Користувач вибрав дію для шерингу');
        break;
      case ShareResultStatus.dismissed:
        debugPrint('Користувач закрив без вибору');
        break;
      case ShareResultStatus.unavailable:
        debugPrint('Шеринг недоступний');
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_currentImages.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1} з ${_currentImages.length}",
          style: const TextStyle(color: Colors.white),
        ),
      ),

      body: PageView.builder(
        controller: _pageController,
        allowImplicitScrolling: true,
        physics: _isZoomed
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        itemCount: _currentImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _isZoomed = false;
          });
        },
        itemBuilder: (context, index) {
          return ZoomableImage(
            file: _currentImages[index],
            index: index,
            currentIndex: _currentIndex,
            onZoomStateChanged: (isZoomed) {
              setState(() {
                _isZoomed = isZoomed;
              });
            },
            onPageForward: () {
              if (_currentIndex < _currentImages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
            onPageBack: () {
              if (_currentIndex > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
          );
        },
      ),

      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.5),
        padding: const .symmetric(vertical: 10, horizontal: 20),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: .spaceAround,
            children: [
              IconButton(
                onPressed: () async {
                  final file = _currentImages[_currentIndex];
                  await _shareContent(
                    file: XFile(file.path),
                  );
                },
                icon: const Icon(Icons.share, color: Colors.white, size: 30),
                tooltip: 'Поділитися',
              ),
              IconButton(
                onPressed: _showImageProperties,
                icon: const Icon(Icons.info_outline, color: Colors.white, size: 30),
                tooltip: 'Властивості',
              ),
              IconButton(
                onPressed: _deletePhoto,
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                tooltip: 'Видалити',
              ),
            ],
          ),
        ),
      ),
    );
  }
}