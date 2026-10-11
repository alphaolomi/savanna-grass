import 'package:flutter/foundation.dart' show kIsWeb;

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
  /// int4, in MediaPipe `.task` form (~550 MB, downloaded once). The browser
  /// build needs the `-web.task` variant, which MediaPipe runs on WebGPU.
  static const modelUrl = String.fromEnvironment(
    'GEMMA_MODEL_URL',
    defaultValue: kIsWeb ? _gemma1bWeb : _gemma1bMobile,
  );

  static const _gemma1bMobile =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';
  static const _gemma1bWeb =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4-web.task';

  /// Hugging Face read token for an account that has accepted the Gemma
  /// licence. Empty means "try without one" (works for ungated mirrors).
  static const hfToken = String.fromEnvironment('HF_TOKEN');

  static const modelLabel = 'Gemma 3 1B';
}
