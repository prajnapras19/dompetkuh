/// Web OAuth client ID from Google Cloud Console (Credentials -> OAuth 2.0
/// Client IDs -> type "Web application"). Required on Android by
/// google_sign_in v7's Credential Manager-based flow, even though this app
/// only signs in on Android — see CLAUDE.md's Phase 4 section for the full
/// manual setup this depends on (OAuth consent screen + Android client with
/// this project's SHA-1 + this Web client).
///
/// A client ID is a public identifier (not a secret — unlike a client
/// *secret*, which this app never needs since it has no server component),
/// so it's fine to commit. Still overridable at build time if it ever needs
/// to change without a code edit:
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '651616440036-c657ap1bu9hs6bjhjbtgb4ipr0s5gc5o.apps.googleusercontent.com',
);
