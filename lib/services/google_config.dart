/// Web OAuth client ID from Google Cloud Console (Credentials -> OAuth 2.0
/// Client IDs -> type "Web application"). Required on Android by
/// google_sign_in v7's Credential Manager-based flow, even though this app
/// only signs in on Android — see README/CLAUDE.md's Phase 4 section for
/// the full manual setup this depends on.
///
/// Not hardcoded here since it's environment/project-specific: pass it at
/// build time, e.g.
///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com
/// Empty until configured; the backup screen shows a setup-needed state
/// instead of attempting sign-in when this is blank.
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
