/// Build-time configuration, passed with `--dart-define`.
///
/// Nothing secret is committed: the Hugging Face token is only needed to
/// download the gated Gemma weights once, and is supplied at build time.
abstract final class Config {
  /// SavannaTime API origin, without the `/api/v1` suffix.
  static const apiUrl = String.fromEnvironment(
    'SAVANNA_API_URL',
    defaultValue: 'https://api.savannatime.com',
  );

  /// Open-weight model the app runs on-device. Gemma 3 1B instruction-tuned,
  /// int4, in MediaPipe `.task` form (~550 MB, downloaded once).
  static const modelUrl = String.fromEnvironment(
    'GEMMA_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
  );

  /// Hugging Face read token for an account that has accepted the Gemma
  /// licence. Empty means "try without one" (works for ungated mirrors).
  static const hfToken = String.fromEnvironment('HF_TOKEN');

  static const modelLabel = 'Gemma 3 1B';
}
