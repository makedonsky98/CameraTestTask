import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../extensions/context_extension.dart';
import '../widgets/video_player_item.dart';
import '../widgets/zoomable_image.dart';

class MediaViewScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const MediaViewScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<MediaViewScreen> createState() => _MediaViewScreenState();
}

class _MediaViewScreenState extends State<MediaViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<File> _currentImages;
  bool _isZoomed = false;
  bool _wasModified = false;

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

  bool _isVideo(File file) {
    return file.path.toLowerCase().endsWith('.mp4');
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
      final isVideo = _isVideo(file);

      final stat = await file.stat();
      final sizeString = _formatFileSize(stat.size);
      final dateString = _formatDate(stat.modified);
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toUpperCase();

      String resolutionString = "";
      String typeString = isVideo ? "Відео ($extension)" : "Фото ($extension)";

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );
      }

      if (isVideo) {
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.file(file);
          await controller.initialize();

          if (controller.value.isInitialized) {
            final size = controller.value.size;
            if (size.width > 0 && size.height > 0) {
              resolutionString = "${size.width.toInt()} x ${size.height.toInt()}";
            }
          }
        } catch (e) {
          debugPrint("Не вдалося отримати метадані відео: $e");
        } finally {
          await controller?.dispose();
        }
      } else {
        try {
          final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          resolutionString = "${descriptor.width} x ${descriptor.height}";
          descriptor.dispose();
          buffer.dispose();
        } catch (e) {
          debugPrint("Не вдалося отримати метадані фото: $e");
        }
      }

      if (!mounted) return;
      if (context.canPop()) context.pop();

      final typeDisplayValue = resolutionString.isNotEmpty
          ? "$typeString, $resolutionString"
          : typeString;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "Властивості",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isVideo && resolutionString.isNotEmpty) ...[
                _buildPropertyRow(Icons.image_aspect_ratio, "Розмір:", resolutionString),
                const SizedBox(height: 12),
              ],

              _buildPropertyRow(
                  isVideo ? Icons.videocam : Icons.image,
                  "Тип:",
                  typeDisplayValue
              ),

              const SizedBox(height: 12),
              _buildPropertyRow(Icons.data_usage, "Вага:", sizeString),
              const SizedBox(height: 12),
              _buildPropertyRow(Icons.calendar_today, "Дата:", dateString),
              const SizedBox(height: 12),
              _buildPropertyRow(Icons.folder_open, "Ім'я:", fileName),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("ОК"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted && context.canPop()) context.pop();
      debugPrint("Критична помилка властивостей: $e");
    }
  }

  Widget _buildPropertyRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
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
          "Видалити файл?",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        content: const Text(
          "Цю дію не можна скасувати.",
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        _wasModified = true;

        if (_currentIndex >= _currentImages.length) {
          _currentIndex = _currentImages.length - 1;
        }
      });

      if (_currentImages.isEmpty) {
        if (mounted) context.pop(true);
      }
    } catch (e) {
      debugPrint("Помилка видалення: $e");

      if (mounted) {
        context.showErrorSnackBar("Помилка: $e");
      }
    }
  }

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.pop(_wasModified);
      },
      child: Scaffold(
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
          allowImplicitScrolling: false,
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
            final file = _currentImages[index];

            if (_isVideo(file)) {
              return VideoPlayerItem(file: file);
            } else {
              return ZoomableImage(
                file: file,
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
            }
          },
        ),

        bottomNavigationBar: Container(
          color: Colors.black.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
      ),
    );
  }
}