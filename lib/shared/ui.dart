import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'haptics.dart';
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
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppPalette.of(context).muted,
              fontWeight: FontWeight.w700,
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
    this.detail,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  /// Extra content under the subtitle, such as a status pill.
  final Widget? detail;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconTile(icon, color),
    title: Text(title),
    subtitle: detail == null
        ? (subtitle == null ? null : Text(subtitle!))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null) Text(subtitle!),
              const SizedBox(height: 6),
              detail!,
            ],
          ),
    trailing: trailing ?? (onTap == null ? null : const Chevron()),
    onTap: onTap,
  );
}

/// Wraps [onChanged] so flipping a switch gives a tick. The Material switch
/// makes none of its own, not even in its iOS look.
ValueChanged<bool>? _tickOnToggle(ValueChanged<bool>? onChanged) =>
    onChanged == null
    ? null
    : (value) {
        Haptics.selection();
        onChanged(value);
      };

/// A platform switch that ticks when it flips.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) =>
      Switch.adaptive(value: value, onChanged: _tickOnToggle(onChanged));
}

/// A list tile with a platform switch that ticks when it flips. Tapping the
/// row flips the switch, like a [SwitchListTile].
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: ListTile(
        title: title,
        subtitle: subtitle,
        contentPadding: contentPadding,
        enabled: onChanged != null,
        trailing: AppSwitch(value: value, onChanged: onChanged),
        // A tap on the rest of the row does not reach the switch.
        onTap: onChanged == null
            ? null
            : () {
                Haptics.selection();
                onChanged(!value);
              },
      ),
    );
  }
}

/// A pull to refresh with the platform's spinner and a haptic tap when the
/// pull goes far enough to start.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  @override
  Widget build(BuildContext context) => RefreshIndicator.adaptive(
    edgeOffset: edgeOffset,
    onRefresh: () {
      Haptics.refresh();
      return onRefresh();
    },
    child: child,
  );
}

/// How long a gauge takes to settle on a new value.
const gaugeDuration = Duration(milliseconds: 600);

/// The curve gauges and the numbers inside them share.
const gaugeCurve = Curves.easeOutCubic;

/// A ring gauge drawn from one or more segments (fractions of the whole)
/// over a track, with a centred child. The ring sweeps in when it first
/// appears and glides to each new value after that; with the system's
/// reduce-motion setting on, it jumps instead.
class RingGauge extends StatefulWidget {
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
  State<RingGauge> createState() => _RingGaugeState();
}

class _RingGaugeState extends State<RingGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: gaugeDuration,
  );

  /// Where the current animation started and where it is headed.
  late List<(double, Color)> _from = [
    for (final (_, color) in widget.segments) (0.0, color),
  ];
  late List<(double, Color)> _to = widget.segments;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didUpdateWidget(RingGauge old) {
    super.didUpdateWidget(old);
    if (!_sameSegments(old.segments, widget.segments)) {
      // Start from what is on screen now, so a value that changes mid-glide
      // does not jump back.
      _from = _current;
      _to = widget.segments;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(double, Color)> get _current =>
      _lerpSegments(_from, _to, gaugeCurve.transform(_controller.value));

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _RingPainter(
            segments: still ? widget.segments : _current,
            track: track,
            stroke: widget.stroke,
          ),
          child: child,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

bool _sameSegments(List<(double, Color)> a, List<(double, Color)> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

/// Segments between [from] and [to]. When one list is shorter, its missing
/// segments grow from or shrink to nothing in the other's colour.
List<(double, Color)> _lerpSegments(
  List<(double, Color)> from,
  List<(double, Color)> to,
  double t,
) => [
  for (var i = 0; i < math.max(from.length, to.length); i++)
    (
      ui.lerpDouble(
        i < from.length ? from[i].$1 : 0,
        i < to.length ? to[i].$1 : 0,
        t,
      )!,
      Color.lerp(
        i < from.length ? from[i].$2 : to[i].$2,
        i < to.length ? to[i].$2 : from[i].$2,
        t,
      )!,
    ),
];

/// A percentage that counts up to its value and between values, in step with
/// the [RingGauge] around it.
class AnimatedPercent extends StatelessWidget {
  const AnimatedPercent(this.percent, {super.key, this.style});

  /// 0 to 100.
  final double percent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text('${percent.round()}%', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent),
      duration: gaugeDuration,
      curve: gaugeCurve,
      builder: (context, value, _) => Text('${value.round()}%', style: style),
    );
  }
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
      !_sameSegments(old.segments, segments);
}

/// Muted text on a card, for an empty section.
class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: TextStyle(color: AppPalette.of(context).muted)),
    ),
  );
}

/// A headed section of rows on one card, or [empty] when there are none.
List<Widget> groupedSection(
  String title,
  List<Widget> rows, {
  String? empty,
  Widget? trailing,
  double indent = 16,
}) => [
  SectionHeader(title, trailing: trailing),
  if (rows.isEmpty && empty != null)
    EmptyCard(empty)
  else if (rows.isNotEmpty)
    GroupedCard(indent: indent, children: rows),
];

/// A glyph in [color] on a soft tint of it, for status-coloured rows.
class SoftIcon extends StatelessWidget {
  const SoftIcon(this.icon, this.color, {super.key, this.semanticLabel});

  final IconData icon;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 22, color: color, semanticLabel: semanticLabel),
  );
}
