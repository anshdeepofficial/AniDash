class NotificationSoundItem {
  final String id;
  final String name;
  final String anime;
  final String description;
  final String? assetPath;
  final String? rawResName;

  const NotificationSoundItem({
    required this.id,
    required this.name,
    required this.anime,
    required this.description,
    this.assetPath,
    this.rawResName,
  });

  bool get isDefault => id == 'system_default';
}

const List<NotificationSoundItem> kNotificationSounds = [
  NotificationSoundItem(
    id: 'anime_nezuko',
    name: 'Nezuko-chan!',
    anime: 'Demon Slayer',
    description: "Zenitsu's iconic passionate scream: 'Nezuko-chan!'",
    assetPath: 'assets/sounds/anime_nezuko.wav',
    rawResName: 'anime_nezuko',
  ),
  NotificationSoundItem(
    id: 'anime_biwa',
    name: 'Infinity Castle Biwa',
    anime: 'Demon Slayer',
    description: "Nakime's authentic castle-shifting Satsuma Biwa strum",
    assetPath: 'assets/sounds/anime_biwa.wav',
    rawResName: 'anime_biwa',
  ),
  NotificationSoundItem(
    id: 'anime_shinobu',
    name: 'Ara Ara~ Sayonara',
    anime: 'Demon Slayer',
    description: "Shinobu Kocho's gentle and eerie greeting",
    assetPath: 'assets/sounds/anime_shinobu.wav',
    rawResName: 'anime_shinobu',
  ),
  NotificationSoundItem(
    id: 'anime_tanjiro',
    name: 'Ano, Sumimasen!',
    anime: 'Demon Slayer',
    description: "Tanjiro Kamado's polite and determined call",
    assetPath: 'assets/sounds/anime_tanjiro.wav',
    rawResName: 'anime_tanjiro',
  ),
  NotificationSoundItem(
    id: 'anime_gojo',
    name: 'Ryouiki Tenkai (Domain Expansion)',
    anime: 'Jujutsu Kaisen',
    description: "Gojo Satoru: 'Ryouiki Tenkai - Muryoukuusho'",
    assetPath: 'assets/sounds/anime_gojo.wav',
    rawResName: 'anime_gojo',
  ),
  NotificationSoundItem(
    id: 'anime_sukuna',
    name: 'Fuga (Open)',
    anime: 'Jujutsu Kaisen',
    description: "Ryomen Sukuna's menacing 'Fuga' Fire Arrow invocation",
    assetPath: 'assets/sounds/anime_sukuna.wav',
    rawResName: 'anime_sukuna',
  ),
  NotificationSoundItem(
    id: 'anime_denden_mushi',
    name: 'Den Den Mushi (Purupurupuru)',
    anime: 'One Piece',
    description: "Iconic snail ring 'Purupurupuru... Gacha!'",
    assetPath: 'assets/sounds/anime_denden_mushi.wav',
    rawResName: 'anime_denden_mushi',
  ),
  NotificationSoundItem(
    id: 'anime_luffy_gear5',
    name: 'Gear 5 Joyboy Laugh',
    anime: 'One Piece',
    description: "Drums of Liberation with Luffy's laughter",
    assetPath: 'assets/sounds/anime_luffy_gear5.wav',
    rawResName: 'anime_luffy_gear5',
  ),
  NotificationSoundItem(
    id: 'anime_bankai',
    name: 'BANKAI!',
    anime: 'Bleach',
    description: "Ichigo Kurosaki's epic 'BANKAI!' roar",
    assetPath: 'assets/sounds/anime_bankai.wav',
    rawResName: 'anime_bankai',
  ),
  NotificationSoundItem(
    id: 'anime_naruto_jutsu',
    name: 'Fire Style: Fireball Jutsu',
    anime: 'Naruto',
    description: "'Katon: Goukakyuu no Jutsu!' invocation",
    assetPath: 'assets/sounds/anime_naruto_jutsu.wav',
    rawResName: 'anime_naruto_jutsu',
  ),
  NotificationSoundItem(
    id: 'anime_ultra_instinct',
    name: 'Ultra Instinct Theme',
    anime: 'Dragon Ball Super',
    description: 'Iconic brass orchestral clash of Mastered Ultra Instinct',
    assetPath: 'assets/sounds/anime_ultra_instinct.wav',
    rawResName: 'anime_ultra_instinct',
  ),
  NotificationSoundItem(
    id: 'anime_dbz_teleport',
    name: 'Instant Transmission',
    anime: 'Dragon Ball Z',
    description: "Goku's high-speed dimensional teleportation SFX",
    assetPath: 'assets/sounds/anime_dbz_teleport.wav',
    rawResName: 'anime_dbz_teleport',
  ),
  NotificationSoundItem(
    id: 'anime_kono_dio_da',
    name: 'Kono DIO Da!',
    anime: "JoJo's Bizarre Adventure",
    description: "Dio Brando's legendary declaration: 'Kono DIO da!'",
    assetPath: 'assets/sounds/anime_kono_dio_da.wav',
    rawResName: 'anime_kono_dio_da',
  ),
  NotificationSoundItem(
    id: 'anime_za_warudo',
    name: 'Za Warudo! (Time Stop)',
    anime: "JoJo's Bizarre Adventure",
    description: "'Za Warudo! Toki yo Tomare!' with sound rift effect",
    assetPath: 'assets/sounds/anime_za_warudo.wav',
    rawResName: 'anime_za_warudo',
  ),
  NotificationSoundItem(
    id: 'anime_megumin',
    name: 'EXPLOSION!',
    anime: 'KonoSuba',
    description: "Megumin's signature powerful chant and explosion",
    assetPath: 'assets/sounds/anime_megumin.wav',
    rawResName: 'anime_megumin',
  ),
  NotificationSoundItem(
    id: 'system_default',
    name: 'System Default',
    anime: 'Device',
    description: "Your phone's standard notification ringtone",
    assetPath: null,
    rawResName: null,
  ),
];
