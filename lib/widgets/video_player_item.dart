import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerItem extends StatefulWidget {
  final File file;

  const VideoPlayerItem({
    super.key,
    required this.file
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });

    _controller.addListener(() {
      if (mounted) {
        final isPlaying = _controller.value.isPlaying;
        if (isPlaying != _isPlaying) {
          setState(() {
            _isPlaying = isPlaying;
          });
        }
        if (_controller.value.position >= _controller.value.duration) {
          setState(() {
            _isPlaying = false;
            _showControls = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _showControls = true);
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          alignment: .center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            if (_showControls || !_isPlaying) ...[
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: .circle,
                  ),
                  padding: const .all(16),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),

              Align(
                alignment: .bottomCenter,
                child: Padding(
                  padding: const .only(bottom: 80.0),
                  child: Container(
                    padding: const .symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: .circular(20),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, VideoPlayerValue value, child) {
                        return Text(
                          "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: .w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}