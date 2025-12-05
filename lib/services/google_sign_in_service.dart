import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  GoogleSignInService._();

  static final GoogleSignIn instance = GoogleSignIn.instance;
  static Future<void>? _initialization;

  static Future<void> ensureInitialized() {
    return _initialization ??= instance.initialize();
  }

  static Future<String?> requestAccessToken({
    required GoogleSignInAccount account,
    required List<String> scopes,
    bool promptIfNecessary = true,
  }) async {
    try {
      final client = account.authorizationClient;
      final existing = await client.authorizationForScopes(scopes);
      if (existing != null) {
        return existing.accessToken;
      }
      if (!promptIfNecessary) {
        return null;
      }
      final granted = await client.authorizeScopes(scopes);
      return granted.accessToken;
    } on GoogleSignInException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
