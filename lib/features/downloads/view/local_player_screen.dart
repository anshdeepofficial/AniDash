import 'package:flutter/material.dart';
import 'package:ani_dash/helpers/ui.dart';
import 'package:ani_dash/features/watch/view/widgets/player/shonenx_video_player.dart';

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
  @override
  void initState() {
    super.initState();
    UIHelper.enableImmersiveMode();
    UIHelper.forceLandscape();
  }

  @override
  void dispose() {
    UIHelper.forcePortrait();
    UIHelper.exitImmersiveMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await UIHelper.forcePortrait();
        await UIHelper.exitImmersiveMode();
        if (context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AniDashVideoPlayer(
          localFilePath: widget.filePath,
          localTitle: widget.title,
        ),
      ),
    );
  }
}
