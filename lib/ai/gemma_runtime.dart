import 'package:flutter_gemma/flutter_gemma.dart';

import '../config.dart';

/// The open-weight model, running entirely on this phone.
///
/// The weights are downloaded once, then every generation happens offline on
/// the device's GPU (CPU fallback). Screen-time data is handed to the model as
/// a prompt string in memory and goes nowhere else — that is the whole point:
/// SavannaTime's rule is that no activity data ever reaches an external AI
/// vendor, and a closed API would break it.
class GemmaRuntime {
  InferenceModel? _model;

  String get modelId => Uri.parse(Config.modelUrl).pathSegments.last;

  Future<bool> isInstalled() => FlutterGemma.isModelInstalled(modelId);

  /// Downloads (first run) or re-activates (later runs) the model. Installing
  /// an already-present file skips the download and only marks it active.
  Future<void> install({void Function(int percent)? onProgress}) async {
    var builder = FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.task,
    ).fromNetwork(
      Config.modelUrl,
      token: Config.hfToken.isEmpty ? null : Config.hfToken,
    );
    if (onProgress != null) builder = builder.withProgress(onProgress);
    await builder.install();
  }

  Future<String> generate(String prompt) async {
    _model ??= await _load();
    final session = await _model!.createSession(
      temperature: 0.9,
      topK: 40,
      topP: 0.95,
      // A fresh seed per quest, or the same day would always get the same one.
      randomSeed: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await session.getResponse();
    } finally {
      await session.close();
    }
  }

  Future<InferenceModel> _load() async {
    try {
      return await FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.gpu,
      );
    } catch (_) {
      // Phones without a usable GPU delegate still run a 1B model on CPU.
      return FlutterGemma.getActiveModel(
        maxTokens: 1024,
        preferredBackend: PreferredBackend.cpu,
      );
    }
  }

  Future<void> close() async {
    await _model?.close();
    _model = null;
  }
}
