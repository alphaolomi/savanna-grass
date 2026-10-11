/// Non-web builds never use the browser engine; see web_llm.dart.
class WebLlm {
  Future<String> generate(String prompt, {required String modelUrl, String prefill = ''}) =>
      throw UnsupportedError('WebLlm is only available on the web');

  void close() {}
}
