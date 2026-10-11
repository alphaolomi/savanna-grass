import 'package:flutter/material.dart';

import '../domain/quest.dart' show formatDuration;
import '../domain/screen_day.dart';
import 'levels.dart';

/// One horizontal bar split by productivity level, most productive on the
/// left, uncategorized last.
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.secondsByLevel, this.uncategorizedSeconds = 0, this.height = 14});

  final Map<int, int> secondsByLevel;
  final int uncategorizedSeconds;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final parts = [
      for (final l in Levels.order)
        if ((secondsByLevel[l] ?? 0) > 0) (Levels.color(c, l), secondsByLevel[l]!),
      if (uncategorizedSeconds > 0) (Levels.color(c, null), uncategorizedSeconds),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: parts.isEmpty
            ? ColoredBox(color: c.surfaceContainerHighest)
            // Stretch: a bare ColoredBox in a Row is otherwise given no height.
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (color, seconds) in parts)
                    Expanded(
                      flex: seconds,
                      child: ColoredBox(color: color),
                    ),
                ],
              ),
      ),
    );
  }
}

/// The rows under a [LevelBar]: colour, label, time and share of the day.
class LevelLegend extends StatelessWidget {
  const LevelLegend({super.key, required this.secondsByLevel, required this.uncategorizedSeconds});

  final Map<int, int> secondsByLevel;
  final int uncategorizedSeconds;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = [
      for (final l in Levels.order) (l, secondsByLevel[l] ?? 0),
      (null, uncategorizedSeconds),
    ].where((r) => r.$2 > 0).toList();
    final total = rows.fold(0, (s, r) => s + r.$2);
    if (total == 0) {
      return Text('Nothing tracked.', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant));
    }
    return Column(
      children: [
        for (final (level, seconds) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: Levels.color(t.colorScheme, level), shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(Levels.label(level), style: t.textTheme.bodyMedium)),
                Text(formatDuration(seconds), style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(seconds * 100 / total).round()}%',
                    textAlign: TextAlign.right,
                    style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A local day as 24 stacked columns — productive at the bottom, distracting
/// on top — with a leaf under every hour that had time outside.
class HourChart extends StatelessWidget {
  const HourChart({super.key, required this.hours, required this.outdoorSecondsByHour, this.height = 120});

  /// 24 entries, hour 0 first.
  final List<HourSlice> hours;

  /// 24 entries, hour 0 first.
  final List<int> outdoorSecondsByHour;
  final double height;

  static String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = t.colorScheme;
    // Scale to the busiest hour, but never below 15 minutes, so a quiet day
    // is not drawn as if every hour were full.
    final peak = hours.fold(15 * 60, (m, h) => h.totalSeconds > m ? h.totalSeconds : m);
    final muted = t.textTheme.labelSmall?.copyWith(color: c.onSurfaceVariant, fontSize: 10);

    Widget segment(int seconds, Color color) =>
        seconds == 0 ? const SizedBox.shrink() : Container(height: height * seconds / peak, color: color);

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in hours)
                Expanded(
                  child: Tooltip(
                    message:
                        '${_hh(h.hour)} · ${formatDuration(h.totalSeconds)} on screens'
                        '${outdoorSecondsByHour[h.hour] >= 60 ? ' · ${outdoorSecondsByHour[h.hour] ~/ 60}m outside' : ''}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: h.totalSeconds == 0
                              ? [Container(height: 2, color: c.surfaceContainerHighest)]
                              : [
                                  segment(h.distractingSeconds, Levels.color(c, -2)),
                                  segment(h.otherSeconds, Levels.color(c, 0)),
                                  segment(h.productiveSeconds, Levels.color(c, 2)),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var h = 0; h < 24; h++)
              Expanded(
                child: Center(
                  child: outdoorSecondsByHour[h] >= 60
                      ? Icon(Icons.park, size: 10, color: c.primary)
                      : const SizedBox(height: 10),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            for (final h in const [0, 6, 12, 18]) Expanded(child: Text(_hh(h), style: muted)),
          ],
        ),
      ],
    );
  }
}
