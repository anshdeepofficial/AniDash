import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ani_dash/shared/providers/anilist_service_provider.dart';
import 'package:ani_dash/shared/providers/mal_service_provider.dart';

import 'package:ani_dash/core/repositories/anime_repository.dart';

import 'package:ani_dash/core/services/auth_provider_enum.dart';
import 'package:ani_dash/shared/auth/providers/auth_notifier.dart';

final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  final auth = ref.watch(authProvider);

  if (auth.activePlatform == AuthPlatform.mal) {
    return ref.read(malServiceProvider);
  } else {
    return ref.read(anilistServiceProvider);
  }
});
