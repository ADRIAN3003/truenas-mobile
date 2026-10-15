import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// A white glyph on a rounded, solid colour square.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, this.color, {super.key, this.size = 32});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Icon(icon, size: size * 0.6, color: Colors.white),
  );
}

/// A rounded pill with a dot and a short label, such as ONLINE or DEGRADED.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, background) = AppPalette.of(context).tone(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A platform-appropriate "go deeper" chevron.
class Chevron extends StatelessWidget {
  const Chevron({super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.of(context).muted;
    return isCupertino(context)
        ? Icon(CupertinoIcons.chevron_forward, size: 18, color: color)
        : Icon(Icons.chevron_right, color: color);
  }
}

/// A small heading above a group of rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppPalette.of(context).muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// An inset group: rows on one card, separated by hairlines that start
/// after the leading icon.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.indent = 64});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(indent: indent),
          children[i],
        ],
      ],
    ),
  );
}

/// A navigation row with an icon tile, title, optional subtitle and chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconTile(icon, color),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: trailing ?? (onTap == null ? null : const Chevron()),
    onTap: onTap,
  );
}

/// A ring gauge drawn from one or more segments (fractions of the whole)
/// over a track, with a centred child.
class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
    required this.segments,
    required this.child,
    this.size = 112,
    this.stroke = 10,
  });

  final List<(double, Color)> segments;
  final Widget child;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        segments: segments,
        track: Theme.of(context).colorScheme.surfaceContainerHighest,
        stroke: stroke,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.segments,
    required this.track,
    required this.stroke,
  });

  final List<(double, Color)> segments;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    var start = -math.pi / 2;
    for (final (fraction, color) in segments) {
      final sweep = math.pi * 2 * fraction.clamp(0, 1);
      if (sweep < 0.01) continue;
      canvas.drawArc(rect, start, sweep, false, paint..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.track != track ||
      old.stroke != stroke ||
      old.segments.length != segments.length ||
      [for (var i = 0; i < segments.length; i++) old.segments[i] != segments[i]]
          .any((changed) => changed);
}

/// A dialog button: a Cupertino action on iOS, a Material button elsewhere.
Widget dialogAction(
  BuildContext context, {
  required String label,
  required VoidCallback? onPressed,
  bool primary = false,
  bool destructive = false,
}) {
  if (isCupertino(context)) {
    return CupertinoDialogAction(
      onPressed: onPressed,
      isDefaultAction: primary,
      isDestructiveAction: destructive,
      child: Text(label),
    );
  }
  if (!primary && !destructive) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
  final scheme = Theme.of(context).colorScheme;
  return FilledButton(
    style: destructive
        ? FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          )
        : null,
    onPressed: onPressed,
    child: Text(label),
  );
}
