import 'dart:js_interop';

/// Runs the model in the browser through MediaPipe GenAI directly.
///
/// flutter_gemma 0.13's web session cannot be reused: it never clears its
/// prompt after an answer, and closing it shuts the engine down — so every
/// quest meant reloading 700 MB onto the GPU. Here the engine is created once
/// (web/vendor/savanna_llm.js) and each quest is one stateless
/// `generateResponse` call. The plugin still downloads and caches the weights.
///
/// Unlike MediaPipe on Android, the web runtime does not apply the model's
/// chat template, and without it Gemma degenerates into empty code fences.
/// So the prompt is wrapped in Gemma's turn markers here, and the answer is
/// pre-filled with [prefill] so the model can only continue in our format.
class WebLlm {
  _LlmInference? _engine;

  /// The cache flutter_gemma stores downloaded models in (WebCacheService).
  static const _cacheName = 'flutter_gemma_models';

  Future<String> generate(String prompt, {required String modelUrl, String prefill = ''}) async {
    _engine ??= await _create(modelUrl);
    final templated = '<start_of_turn>user\n$prompt<end_of_turn>\n<start_of_turn>model\n$prefill';
    final answer = (await _engine!.generateResponse(templated.toJS).toDart).toDart;
    return '$prefill$answer';
  }

  Future<_LlmInference> _create(String modelUrl) async {
    final options = {
      'maxTokens': 1024,
      'topK': 40,
      'temperature': 0.8,
      'randomSeed': DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    }.jsify()! as JSObject;
    return _savannaLlm.create(_cacheName.toJS, _normalize(modelUrl).toJS, options).toDart;
  }

  /// Mirrors flutter_gemma's UrlUtils.normalizeUrl: no query, no trailing slash.
  static String _normalize(String url) {
    final uri = Uri.parse(url);
    var s = uri.hasQuery ? uri.replace(query: '').toString() : uri.toString();
    if (s.endsWith('?')) s = s.substring(0, s.length - 1);
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  void close() {
    _engine?.close();
    _engine = null;
  }
}

@JS('savannaLlm')
external _SavannaLlm get _savannaLlm;

extension type _SavannaLlm._(JSObject _) implements JSObject {
  external JSPromise<_LlmInference> create(JSString cacheName, JSString modelUrl, JSObject options);
}

extension type _LlmInference._(JSObject _) implements JSObject {
  external JSPromise<JSString> generateResponse(JSString prompt);
  external void close();
}
