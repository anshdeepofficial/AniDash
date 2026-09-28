import 'dart:convert';
import 'package:ani_dash/core/services/oauth/base_oauth_service.dart';
import 'package:ani_dash/core/utils/env_loader.dart';

class AniListAuthService extends BaseOAuthService {
  String get _clientId =>
      isDesktop
          ? ANILIST_CLIENT_ID.split('|')[1]
          : ANILIST_CLIENT_ID.split('|')[0];
  String get _clientSecret =>
      isDesktop
          ? ANILIST_CLIENT_SECRET.split('|')[1]
          : ANILIST_CLIENT_SECRET.split('|')[0];

  static const String _authUrl = 'https://anilist.co/api/v2/oauth/authorize';
  static const String _tokenUrl = 'https://anilist.co/api/v2/oauth/token';

  Future<String?> authenticate() async {
    final loginUrl =
        Uri.parse(_authUrl)
            .replace(
              queryParameters: {
                'client_id': _clientId,
                'redirect_uri': redirectUri,
                // Mobile apps cannot keep a client secret. AniList's implicit flow
                // returns a bearer token directly; desktop builds can still use the
                // server-style authorization-code exchange when configured.
                'response_type': isDesktop ? 'code' : 'token',
              },
            )
            .toString();

    final queryParams = await performWebAuth(loginUrl);
    return queryParams?[isDesktop ? 'code' : 'access_token'];
  }

  Future<Map<String, dynamic>?> getAccessToken(String code) async {
    if (!isDesktop) {
      return {'access_token': code, 'token_type': 'Bearer'};
    }
    if (_clientSecret.trim().isEmpty) {
      throw StateError(
        'AniList login is not configured for this build. Provide '
        'ANILIST_CLIENT_SECRET using --dart-define at build time.',
      );
    }
    return await postTokenRequest(
      _tokenUrl,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "grant_type": "authorization_code",
        "client_id": _clientId,
        "client_secret": _clientSecret,
        'redirect_uri': redirectUri,
        "code": code,
      }),
    );
  }
}
