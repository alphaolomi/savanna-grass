import 'package:flutter/foundation.dart' show debugPrint;

import '../config.dart';
import '../domain/quest.dart';

/// Turns today's context into a quest. The model behind it is swappable —
/// on-device Gemma in the app, a fake in tests.
abstract interface class QuestWriter {
  Future<Quest> write(QuestContext context);
}

/// Asks the on-device model, and falls back to a deterministic template when
/// the model is unavailable or its answer does not parse. Either way the person
/// gets a quest: the model makes it personal, it is never load-bearing.
class LocalModelQuestWriter implements QuestWriter {
  LocalModelQuestWriter({
    required this.generate,
    required this.isReady,
  });

  final Future<String> Function(String prompt) generate;
  final bool Function() isReady;
  int _templateSeed = 0;

  /// Why the last quest came from the template, for the UI. Null when the
  /// model wrote it.
  String? lastFallbackReason;

  @override
  Future<Quest> write(QuestContext context) async {
    if (!isReady()) {
      lastFallbackReason = 'model not downloaded';
      return templateQuest(context, seed: _templateSeed++);
    }
    try {
      final raw = await generate(buildQuestPrompt(context));
      if (Config.debugQuests) debugPrint('[quest] raw: $raw');
      final quest = parseQuest(raw, minutes: context.targetMinutes);
      if (quest != null) {
        lastFallbackReason = null;
        if (quest.why.isNotEmpty) return quest;
        return Quest(
          title: quest.title,
          minutes: quest.minutes,
          steps: quest.steps,
          why: twigaWhy(context),
          source: quest.source,
        );
      }
      lastFallbackReason = 'model answer did not parse';
    } catch (e) {
      lastFallbackReason = 'model error: $e';
      if (Config.debugQuests) debugPrint('[quest] error: $e');
    }
    return templateQuest(context, seed: _templateSeed++);
  }
}
