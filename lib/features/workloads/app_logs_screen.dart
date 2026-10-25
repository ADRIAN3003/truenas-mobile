import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/workloads_api.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/dialogs.dart';
import '../../shared/viz_colors.dart';

/// The output of one app container, following it live, without a shell.
class AppLogsScreen extends StatefulWidget {
  const AppLogsScreen({
    super.key,
    required this.session,
    required this.app,
    required this.containerId,
    required this.title,
  });

  final TrueNasSession session;
  final String app;
  final String containerId;
  final String title;

  @override
  State<AppLogsScreen> createState() => _AppLogsScreenState();
}

class _AppLogsScreenState extends State<AppLogsScreen> {
  /// How many lines the server sends first, and the most kept in memory.
  static const _tailChoices = [100, 500, 2000];
  static const _maxLines = 5000;

  /// Lines worth a colour, so a failure stands out in a long log.
  static final _errorWords = RegExp(
    r'\b(error|fatal|panic|exception|critical)\b',
  );
  static final _warning = RegExp(r'\bwarn(ing)?\b');

  final _scroll = ScrollController();
  final _filter = TextEditingController();
  final _lines = <String>[];
  final _pending = <String>[];
  StreamSubscription<AppLogLine>? _logs;
  StreamSubscription<void>? _reconnects;
  Timer? _flush;
  int _tail = 500;
  bool _follow = true;
  bool _filtering = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
    // A new connection is sent the last lines again.
    _reconnects = widget.session.client.reconnected.listen((_) => _clear());
  }

  void _start() {
    _error = null;
    _logs = widget.session.workloads
        .appLogs(widget.app, widget.containerId, tailLines: _tail)
        .listen(
          (line) {
            _pending.add(line.text);
            // The first lines arrive in a burst: draw them together.
            _flush ??= Timer(const Duration(milliseconds: 100), _drain);
          },
          onError: (Object error) {
            if (mounted) setState(() => _error = error);
          },
        );
  }

  Future<void> _restart() async {
    await _logs?.cancel();
    _clear();
    if (mounted) setState(_start);
  }

  void _clear() {
    _flush?.cancel();
    _flush = null;
    _pending.clear();
    if (mounted) setState(_lines.clear);
  }

  void _drain() {
    _flush = null;
    if (!mounted) return;
    setState(() {
      _lines.addAll(_pending);
      _pending.clear();
      if (_lines.length > _maxLines) {
        _lines.removeRange(0, _lines.length - _maxLines);
      }
    });
    if (_follow) WidgetsBinding.instance.addPostFrameCallback(_toEnd);
  }

  void _toEnd([Duration? _]) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    position.jumpTo(position.maxScrollExtent);
    // Lines of different heights are only measured once they are on screen.
    if (position.pixels < position.maxScrollExtent - 1) {
      WidgetsBinding.instance.addPostFrameCallback(_toEnd);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final atEnd = n.metrics.extentAfter < 48;
    // Only the user's own scrolling changes whether it follows.
    if (n is ScrollUpdateNotification && n.dragDetails == null) return false;
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      if (atEnd != _follow) setState(() => _follow = atEnd);
    }
    return false;
  }

  List<String> get _visible {
    final needle = _filter.text.trim().toLowerCase();
    return needle.isEmpty
        ? _lines
        : [
            for (final line in _lines)
              if (line.toLowerCase().contains(needle)) line,
          ];
  }

  Future<void> _copy(List<String> lines) async {
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copied)),
    );
  }

  @override
  void dispose() {
    _flush?.cancel();
    _logs?.cancel();
    _reconnects?.cancel();
    _scroll.dispose();
    _filter.dispose();
    super.dispose();
  }

  Color? _lineColor(BuildContext context, String line) {
    final lower = line.toLowerCase();
    if (_errorWords.hasMatch(lower)) return VizColors.critical;
    if (_warning.hasMatch(lower)) return VizColors.of(context).series2;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: l10n.appLogsFilter,
            icon: Icon(_filtering ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              _filtering = !_filtering;
              if (!_filtering) _filter.clear();
            }),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            icon: const Icon(Icons.copy),
            onPressed: visible.isEmpty ? null : () => _copy(visible),
          ),
          AppPopupMenu<Object>(
            onSelected: (value) {
              if (value case final int tail) {
                if (tail == _tail) return;
                _tail = tail;
                _restart();
              } else {
                _clear();
              }
            },
            entries: [
              for (final tail in _tailChoices)
                menuEntry<Object>(
                  tail,
                  '${tail == _tail ? '✓ ' : ''}${l10n.appLogsLastLines(tail)}',
                ),
              menuEntry<Object>('clear', l10n.appLogsClear),
            ],
          ),
        ],
        bottom: _filtering
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _filter,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.appLogsFilter,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: _follow || visible.isEmpty
          ? null
          : FloatingActionButton.small(
              tooltip: l10n.appLogsFollow,
              onPressed: () {
                setState(() => _follow = true);
                _toEnd();
              },
              child: const Icon(Icons.vertical_align_bottom),
            ),
      body: _error != null && _lines.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      describeConnectError(l10n, _error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _restart,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          : visible.isEmpty
          ? Center(
              child: Text(
                _lines.isEmpty ? l10n.appLogsEmpty : l10n.appLogsNoMatches,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: visible.length,
                  itemBuilder: (_, i) => Text(
                    visible[i],
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                      color: _lineColor(context, visible[i]),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
