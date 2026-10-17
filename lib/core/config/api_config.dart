/// Core API Configuration & Keys
abstract final class ApiConfig {
  /// TMDB API Key (v3)
  /// Injected at runtime via `--dart-define=TMDB_API_KEY=your_key`
  static const String tmdbApiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: 'caaa9028a9289ed5c7908d43ebf34fef',
  );

  /// OMDB API Key (fallback)
  /// Injected at runtime via `--dart-define=OMDB_API_KEY=your_key`
  static const String omdbApiKey = String.fromEnvironment(
    'OMDB_API_KEY',
    defaultValue: 'trilogy',
  );

  /// TMDB Base Image URL for posters (w500 size)
  static const String tmdbImageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  /// TMDB API Base URL
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  /// AI Agent Backend Base URL (Vercel / Cloud Function)
  /// Injected at runtime via `--dart-define=AI_AGENT_BASE_URL=https://your-vercel-domain.vercel.app`
  static const String aiAgentBaseUrl = String.fromEnvironment(
    'AI_AGENT_BASE_URL',
    defaultValue: 'https://backend-three-theta-74.vercel.app',
  );
}
