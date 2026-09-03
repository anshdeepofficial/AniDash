import 'package:commentum_client/commentum_client.dart';
import 'package:flutter/foundation.dart';
import 'package:ani_dash/core/commentum/commentum_storage.dart';
import 'package:ani_dash/core/utils/env_loader.dart';

final commentumClient = CommentumClient(
  config: CommentumConfig(
    baseUrl: COMMENTUM_API_URL,
    appClient: "AniDash",
    enableLogging: kDebugMode,
    verboseLogging: false,
  ),
  preferredProvider: CommentumProvider.anilist,
  storage: CommentumTokenStorage(),
);
