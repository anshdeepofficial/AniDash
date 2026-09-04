import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

void showTutorialSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SafeArea(child: TutorialSheet()),
  );
}

class TutorialSheet extends StatefulWidget {
  const TutorialSheet({super.key});

  @override
  State<TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<TutorialSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Welcome to AniDash Extensions!',
      'description': 'We have moved to a new Extension System for fetching videos. This means you can download your favorite Anime and Manga sources dynamically without app updates!',
      'icon': Iconsax.global_refresh,
    },
    {
      'title': 'Step 1: Go to Settings',
      'description': 'First, open the Settings menu by tapping the gear icon on the top right of the Home screen.',
      'icon': Iconsax.setting_2,
    },
    {
      'title': 'Step 2: Open Extensions',
      'description': 'In Settings, look for the "Extensions" tab. Tap on it to open the extension manager.',
      'icon': Icons.extension_outlined,
    },
    {
      'title': 'Step 3: Install Sources',
      'description': 'You will see a list of available sources. Tap "Install" on the ones you want (like Gojo, Gogoanime, etc.).',
      'icon': Iconsax.document_download,
    },
    {
      'title': 'Step 4: Start Watching!',
      'description': 'Once installed, the app will automatically use them to fetch episodes and streams when you tap on an Anime. Enjoy!',
      'icon': Iconsax.play_circle,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How to Watch',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      step['icon'],
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      step['title'],
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step['description'],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  _steps.length,
                  (index) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _nextPage,
                child: Text(_currentPage == _steps.length - 1 ? 'Got it!' : 'Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
