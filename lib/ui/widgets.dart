import 'package:flutter/material.dart';

import '../persona.dart';

/// Twiga's face: the giraffe on a soft green disc.
class TwigaAvatar extends StatelessWidget {
  const TwigaAvatar({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
      child: Text(Twiga.emoji, style: TextStyle(fontSize: size * 0.52, height: 1)),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.size,
    required this.stroke,
    required this.value,
    required this.color,
    required this.track,
    required this.child,
  });

  final double size;
  final double stroke;
  final double value;
  final Color color;
  final Color track;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: track,
            ),
          ),
          Center(child: child),
        ],
      ),
    );
  }
}

enum PillTone { green, sun }

class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.icon, this.tone = PillTone.green});
  final String text;
  final IconData? icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = tone == PillTone.sun
        ? (c.secondaryContainer, c.onSecondaryContainer)
        : (c.primaryContainer, c.onPrimaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, size: 18, color: c.onSecondaryContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.onSecondaryContainer, fontSize: 13))),
      ]),
    );
  }
}

/// Technical detail kept one tap away instead of in the person's face.
class DetailsButton extends StatelessWidget {
  const DetailsButton({super.key, required this.details});
  final String details;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Details'),
          content: SingleChildScrollView(child: SelectableText(details, style: const TextStyle(fontSize: 12))),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      ),
      child: const Text('Details'),
    );
  }
}
