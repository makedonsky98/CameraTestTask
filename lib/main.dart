import 'package:flutter/material.dart';

import 'extensions/context_extension.dart';

void main() {
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
      ),
      home: const HomePage(title: 'Camera Test Task'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title
  });

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.inversePrimary,
        centerTitle: true,
        title: Text(
          widget.title,
          style: context.text.titleLarge?.copyWith(
            fontWeight: .w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Text(
              'Main Content',
              style: context.text.titleLarge?.copyWith(
                fontWeight: .w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
