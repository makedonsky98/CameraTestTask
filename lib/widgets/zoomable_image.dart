import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../extensions/context_extension.dart';

class ZoomableImage extends StatefulWidget {
  final File file;
  final ValueChanged<bool> onZoomStateChanged;
  final VoidCallback onPageForward;
  final VoidCallback onPageBack;
  final int index;
  final int currentIndex;

  const ZoomableImage({
    super.key,
    required this.file,
    required this.onZoomStateChanged,
    required this.onPageForward,
    required this.onPageBack,
    required this.index,
    required this.currentIndex,
  });

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}


class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      _transformationController.value = _animation!.value;
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentIndex != widget.index) {
      if (_transformationController.value != Matrix4.identity()) {
        _transformationController.value = Matrix4.identity();
      }
    }
  }

  void _handleDoubleTap() {
    Matrix4 endMatrix;
    const double scale = 3.0;
    Offset position = _doubleTapDetails?.localPosition ?? Offset.zero;

    if (_transformationController.value != Matrix4.identity()) {
      endMatrix = Matrix4.identity();
      widget.onZoomStateChanged(false);
    } else {
      final double tx = -position.dx * (scale - 1);
      final double ty = -position.dy * (scale - 1);

      endMatrix = Matrix4.identity()
        ..translateByVector3(vector.Vector3(tx, ty, 0.0))
        ..scaleByVector3(vector.Vector3(scale, scale, 1.0));

      widget.onZoomStateChanged(true);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeOut).animate(_animationController));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: SizedBox.expand(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          clipBehavior: .none,
          onInteractionUpdate: (details) {
            final double scale = _transformationController.value.row0.x;

            if (scale > 1.01) {
              widget.onZoomStateChanged(true);
            } else {
              widget.onZoomStateChanged(false);
            }
          },
          onInteractionEnd: (details) {
            final double scale = _transformationController.value.row0.x;

            if (scale <= 1.01) {
              widget.onZoomStateChanged(false);
              return;
            }

            final double velocityX = details.velocity.pixelsPerSecond.dx;

            if (velocityX.abs() > 500) {
              final double currentX = _transformationController.value.row0.a;
              final double screenWidth = context.width;
              final double boundary = screenWidth - (screenWidth * scale);

              if (velocityX > 0 && currentX >= -10) {
                widget.onPageBack();
              } else if (velocityX < 0 && currentX <= boundary + 10) {
                widget.onPageForward();
              }
            }
          },
          child: Center(
            child: Hero(
              tag: widget.file.path,
              child: Image.file(
                widget.file,
                fit: .contain,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: frame != null
                        ? child
                        : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}