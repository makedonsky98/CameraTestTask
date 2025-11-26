import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

    imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    setState(() {
      _images = imageFiles;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мої фото"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _images.isEmpty
          ? const Center(child: Text("Поки що немає фото"))
          : GridView.builder(
        padding: const .all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final file = _images[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  Scaffold(
                    appBar: AppBar(),
                    body: Center(child: Image.file(file)),
                  )
              ));
            },
            child: Image.file(
              file,
              fit: .cover,
            ),
          );
        },
      ),
    );
  }
}