import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import 'ui.dart';

bool isVideoUrl(String? url) {
  final ext = (url ?? '').split('?').first.split('.').last.toLowerCase();
  return const ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'm4v'].contains(ext);
}

/// Inline network video with tap-to-play/pause and a scrubber.
class NetVideo extends StatefulWidget {
  const NetVideo(this.url, {super.key, this.autoplay = true});
  final String url;
  final bool autoplay;

  @override
  State<NetVideo> createState() => _NetVideoState();
}

class _NetVideoState extends State<NetVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _c
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.autoplay) _c.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _error = true);
        });
    _c.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: Icon(LucideIcons.videoOff, color: Colors.white54, size: 32)),
        ),
      );
    }
    if (!_c.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _c.value.aspectRatio,
      child: GestureDetector(
        onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_c),
            if (!_c.value.isPlaying)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(LucideIcons.play, color: Colors.white, size: 28),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(_c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppColors.saffron)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen photo / video viewer (MediaPreviewModal.js).
Future<void> showMediaPreview(BuildContext context, String url) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: isVideoUrl(url) ? NetVideo(url) : InteractiveViewer(child: NetImage(url, fit: BoxFit.contain)),
      ),
    ),
  ),
);
