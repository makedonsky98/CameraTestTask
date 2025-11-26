import 'package:flutter/material.dart';

import 'extensions/context_extension.dart';
import 'services/permission_service.dart';

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
        colorScheme: .fromSeed(
          seedColor: Colors.blueAccent,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Camera Test'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PermissionService _permissionService = PermissionService();

  bool _hasPermissions = false;
  bool _isLoading = true;
  bool _isRequesting = false;

  String _missingPermissionsText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePermissionStatus();
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequesting) return;

    setState(() {
      _isLoading = true;
      _isRequesting = true;
    });

    final hasAccess = await _permissionService.requestSequentialPermissions();
    await _updateMissingDescription();

    if (!mounted) return;

    setState(() {
      _hasPermissions = hasAccess;
      _isLoading = false;
      _isRequesting = false;
    });
  }

  Future<void> _updatePermissionStatus() async {
    if (_isRequesting) return;

    final hasAccess = await _permissionService.checkStatusOnly();
    await _updateMissingDescription();

    if (!mounted) return;

    setState(() {
      _hasPermissions = hasAccess;
    });
  }

  Future<void> _updateMissingDescription() async {
    final missingList = await _permissionService.getMissingPermissionsDescriptions();

    if (missingList.isEmpty) {
      _missingPermissionsText = '';
    } else {
      _missingPermissionsText = missingList.join(', ');
    }
  }

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
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_hasPermissions) {
      return Column(
        mainAxisAlignment: .center,
        children: [
          Icon(
            Icons.check_circle,
            color: context.colors.primary,
            size: 64,
          ),
          Container(
            width: 0.8 * context.width,
            margin: const .only(top: 16),
            child: Text(
              'Всі дозволи надано',
              textAlign: .center,
              style: context.text.titleLarge,
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: .center,
        children: [
          Icon(
            Icons.error_outline,
            color: context.colors.error,
            size: 64,
          ),
          Container(
            width: 0.8 * context.width,
            margin: const .only(
              top: 16,
              bottom: 24,
            ),
            child: Text.rich(
              TextSpan(
                text: 'Для роботи додатку потрібен доступ до: ',
                style: context.text.bodyLarge,
                children: [
                  TextSpan(
                    text: _missingPermissionsText,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: .w600,
                    ),
                  ),
                  TextSpan(
                    text: '.',
                    style: context.text.bodyLarge,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _permissionService.openSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Відкрити налаштування'),
          ),
        ],
      );
    }
  }
}