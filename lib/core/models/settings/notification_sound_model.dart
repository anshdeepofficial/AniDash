class NotificationSoundItem {
  final String id;
  final String name;
  final String description;
  final String? assetPath;
  final String? rawResName;

  const NotificationSoundItem({
    required this.id,
    required this.name,
    required this.description,
    this.assetPath,
    this.rawResName,
  });

  bool get isDefault => id == 'system_default';
}

const List<NotificationSoundItem> kNotificationSounds = [
  NotificationSoundItem(
    id: 'anidash_biwa',
    name: 'Infinity Castle Biwa',
    description: "Demon Slayer Nakime's iconic castle-shifting biwa strum",
    assetPath: 'assets/sounds/anidash_biwa.wav',
    rawResName: 'anidash_biwa',
  ),
  NotificationSoundItem(
    id: 'anidash_chime',
    name: 'Anime Bell (Default)',
    description: 'Crisp crystalline ascending anime bell chime',
    assetPath: 'assets/sounds/anidash_chime.wav',
    rawResName: 'anidash_chime',
  ),
  NotificationSoundItem(
    id: 'anidash_katana',
    name: 'Katana Slash',
    description: 'Metallic sword draw & air whoosh strike',
    assetPath: 'assets/sounds/anidash_katana.wav',
    rawResName: 'anidash_katana',
  ),
  NotificationSoundItem(
    id: 'anidash_levelup',
    name: 'Level Up',
    description: '8-bit retro arcade power-up chord',
    assetPath: 'assets/sounds/anidash_levelup.wav',
    rawResName: 'anidash_levelup',
  ),
  NotificationSoundItem(
    id: 'anidash_radar',
    name: 'Dragon Radar',
    description: 'Double high-tech sonar beep ping',
    assetPath: 'assets/sounds/anidash_radar.wav',
    rawResName: 'anidash_radar',
  ),
  NotificationSoundItem(
    id: 'anidash_sparkle',
    name: 'Magic Sparkle',
    description: 'Magical star cascade shimmer',
    assetPath: 'assets/sounds/anidash_sparkle.wav',
    rawResName: 'anidash_sparkle',
  ),
  NotificationSoundItem(
    id: 'anidash_jutsu',
    name: 'Ninja Handseal',
    description: 'Percussive wooden handseal pop with chakra tone',
    assetPath: 'assets/sounds/anidash_jutsu.wav',
    rawResName: 'anidash_jutsu',
  ),
  NotificationSoundItem(
    id: 'anidash_teleport',
    name: 'Instant Teleport',
    description: 'Fast sci-fi frequency warp pop',
    assetPath: 'assets/sounds/anidash_teleport.wav',
    rawResName: 'anidash_teleport',
  ),
  NotificationSoundItem(
    id: 'anidash_taiko',
    name: 'Taiko Drum',
    description: 'Authentic Japanese wooden body drum strike',
    assetPath: 'assets/sounds/anidash_taiko.wav',
    rawResName: 'anidash_taiko',
  ),
  NotificationSoundItem(
    id: 'system_default',
    name: 'System Default',
    description: "Your phone's standard notification ringtone",
    assetPath: null,
    rawResName: null,
  ),
];
