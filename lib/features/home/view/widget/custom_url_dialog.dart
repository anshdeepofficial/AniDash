import 'package:flutter/material.dart';
import 'package:ani_dash/core/services/sniffer_service.dart';
import 'package:ani_dash/features/watch/view/custom_video_player_screen.dart';

void showCustomUrlDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const CustomUrlDialog(),
  );
}

class CustomUrlDialog extends StatefulWidget {
  const CustomUrlDialog({super.key});

  @override
  State<CustomUrlDialog> createState() => _CustomUrlDialogState();
}

class _CustomUrlDialogState extends State<CustomUrlDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _extractAndPlay() async {
    final url = _controller.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() {
        _error = 'Please enter a valid website URL.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final streamUrl = await VideoSnifferService.extractVideoUrl(url);
    
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (streamUrl != null) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => CustomVideoPlayerScreen(url: streamUrl)
      ));
    } else {
      setState(() {
        _error = 'Could not find any video stream on this page.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Play Custom Video URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Paste a link to any anime episode page. The app will extract the video stream automatically.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'https://...',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Text('Sniffing video stream... Please wait.', textAlign: TextAlign.center),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _extractAndPlay,
          child: const Text('Play'),
        ),
      ],
    );
  }
}
