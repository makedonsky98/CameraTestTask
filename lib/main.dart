import 'package:flutter/material.dart';

import '/pages/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CameraTestApp());
}

class CameraTestApp extends StatelessWidget {
  const CameraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.blueAccent),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const CameraScreen(title: 'Camera Test'),
    );
  }
}