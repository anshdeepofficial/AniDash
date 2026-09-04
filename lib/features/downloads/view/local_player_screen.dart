import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ani_dash/helpers/ui.dart';

class LocalPlayerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const LocalPlayerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<LocalPlayerScreen> createState() => _LocalPlayerScreenState();
}

class _LocalPlayerScreenState extends State<LocalPlayerScreen> {
  late final Player player;
  late final VideoController controller;

  @override
  void initState() {
    super.initState();
    UIHelper.enableImmersiveMode();
    UIHelper.forceLandscape();
    _initializePlayer();
  }

  @override
  void dispose() {
    UIHelper.forcePortrait();
    UIHelper.exitImmersiveMode();
    UIHelper.enableAutoRotate();
    player.dispose();
    super.dispose();
  }

  void _initializePlayer() async {
    player = Player();
    controller = VideoController(player);
    await player.open(Media(widget.filePath));
  }

  @override
  Widget build(BuildContext context) {
    final topBar = [
      IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          volumeGesture: true,
          brightnessGesture: true,
          seekGesture: true,
          topButtonBar: topBar,
        ),
        fullscreen: MaterialVideoControlsThemeData(
          volumeGesture: true,
          brightnessGesture: true,
          seekGesture: true,
          topButtonBar: topBar,
        ),
        child: Center(
          child: Video(
            controller: controller,
            controls: MaterialVideoControls,
          ),
        ),
      ),
    );
  }
}
