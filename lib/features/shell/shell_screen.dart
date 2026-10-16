import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../core/api/shell_session.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/haptics.dart';

/// A terminal on the server, like System → Shell in the web UI.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    required this.session,
    this.options = const {},
    this.title,
    this.fallbackCommands = const [],
  });

  final TrueNasSession session;

  /// Picks a VM, app or container console instead of the host shell.
  final Map<String, Object?> options;
  final String? title;

  /// Shells to try, in order, when the server's default is not in the
  /// container (an Alpine image has no bash). Used only when the shell dies
  /// on start, before the user has typed anything.
  final List<String> fallbackCommands;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

enum _Status { connecting, connected, closed }

/// What a container runtime prints when the shell it was asked for is not
/// there, e.g. `exec: "/bin/bash": stat /bin/bash: no such file or directory`.
final _missingShell = RegExp(
  'OCI runtime exec failed|executable file not found|no such file or directory',
  caseSensitive: false,
);

class _ShellScreenState extends State<ShellScreen> {
  final _terminal = Terminal(maxLines: 10000);
  final _selection = TerminalController();
  final _focus = FocusNode();
  ShellSession? _shell;
  StreamSubscription<String>? _output;
  _Status _status = _Status.connecting;
  Object? _error;

  /// The first output of this attempt, to tell a shell that never started
  /// from one that ran and ended.
  final _early = StringBuffer();
  var _typed = false;

  /// The fallback shell in use, and how many have been tried.
  String? _command;
  var _fallbacksTried = 0;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) {
      _typed = true;
      _shell?.write(data);
    };
    _terminal.onResize = (cols, rows, _, _) => _shell?.resize(cols, rows);
    _connect();
  }

  @override
  void dispose() {
    _output?.cancel();
    _shell?.close();
    _selection.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _status = _Status.connecting;
      _error = null;
    });
    _early.clear();
    try {
      final shell = await widget.session.openShell(
        options: {...widget.options, 'command': ?_command},
      );
      if (!mounted) {
        await shell.close();
        return;
      }
      _shell = shell;
      _output = shell.output
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            _onOutput,
            onDone: _onDone,
            onError: (Object e) {
              if (mounted) {
                setState(() {
                  _status = _Status.closed;
                  _error = e;
                });
              }
            },
          );
      setState(() => _status = _Status.connected);
      await shell.resize(_terminal.viewWidth, _terminal.viewHeight);
      _focus.requestFocus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = _Status.closed;
          _error = e;
        });
      }
    }
  }

  void _onOutput(String text) {
    if (!_typed && _early.length < 2048) _early.write(text);
    _terminal.write(text);
  }

  void _onDone() {
    if (!mounted) return;
    final next = _nextFallback();
    if (next == null) {
      setState(() => _status = _Status.closed);
    } else {
      _tryFallback(next);
    }
  }

  /// The next shell to try when this one never started, or null.
  String? _nextFallback() {
    if (_typed || _fallbacksTried >= widget.fallbackCommands.length) {
      return null;
    }
    return _missingShell.hasMatch(_early.toString())
        ? widget.fallbackCommands[_fallbacksTried]
        : null;
  }

  Future<void> _tryFallback(String command) async {
    _fallbacksTried++;
    _command = command;
    _terminal.write(
      '\r\n\x1b[2m${AppLocalizations.of(context).shellFallback(command)}'
      '\x1b[0m\r\n',
    );
    await _output?.cancel();
    await _shell?.close();
    _shell = null;
    await _connect();
  }

  Future<void> _restart() async {
    await _output?.cancel();
    await _shell?.close();
    _shell = null;
    _terminal.write('\r\n');
    _typed = false;
    _command = null;
    _fallbacksTried = 0;
    await _connect();
  }

  /// Copies the selected text (long press, then drag to extend) and clears
  /// the selection.
  Future<void> _copy() async {
    final range = _selection.selection;
    if (range == null) return;
    final text = _terminal.buffer.getText(range);
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).shellCopied;
    await Clipboard.setData(ClipboardData(text: text));
    _selection.clearSelection();
    Haptics.confirm();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Types the clipboard into the shell, as a paste when the program asks
  /// for bracketed paste.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    Haptics.selection();
    // Line breaks are Enter keys in a terminal.
    _terminal.paste(text.replaceAll(RegExp(r'\r?\n'), '\r'));
    _focus.requestFocus();
  }

  void _key(TerminalKey key, {bool ctrl = false}) {
    Haptics.selection();
    _terminal.keyInput(key, ctrl: ctrl);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.shellTitle)),
      body: SafeArea(
        child: Column(
          children: [
            if (_status == _Status.connecting)
              const LinearProgressIndicator()
            else if (_status == _Status.closed)
              MaterialBanner(
                content: Text(
                  error == null
                      ? l10n.shellClosed
                      : describeConnectError(l10n, error),
                ),
                actions: [
                  TextButton(
                    onPressed: _restart,
                    child: Text(l10n.shellReconnect),
                  ),
                ],
              ),
            Expanded(
              child: TerminalView(
                _terminal,
                controller: _selection,
                focusNode: _focus,
                autofocus: true,
                readOnly: _status != _Status.connected,
                textStyle: const TerminalStyle(fontSize: 13),
                padding: const EdgeInsets.all(4),
              ),
            ),
            Material(
              color: theme.colorScheme.surfaceContainer,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    ListenableBuilder(
                      listenable: _selection,
                      builder: (context, _) => _KeyButton(
                        label: l10n.copy,
                        icon: Icons.copy_rounded,
                        onPressed: _selection.selection == null ? null : _copy,
                      ),
                    ),
                    _KeyButton(
                      label: l10n.shellPaste,
                      icon: Icons.content_paste_rounded,
                      onPressed: _status == _Status.connected ? _paste : null,
                    ),
                    const SizedBox(
                      height: 24,
                      child: VerticalDivider(width: 12),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyEsc,
                      onPressed: () => _key(TerminalKey.escape),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyTab,
                      onPressed: () => _key(TerminalKey.tab),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyCtrlC,
                      onPressed: () => _key(TerminalKey.keyC, ctrl: true),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyUp,
                      icon: Icons.keyboard_arrow_up,
                      onPressed: () => _key(TerminalKey.arrowUp),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyDown,
                      icon: Icons.keyboard_arrow_down,
                      onPressed: () => _key(TerminalKey.arrowDown),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyLeft,
                      icon: Icons.keyboard_arrow_left,
                      onPressed: () => _key(TerminalKey.arrowLeft),
                    ),
                    _KeyButton(
                      label: l10n.shellKeyRight,
                      icon: Icons.keyboard_arrow_right,
                      onPressed: () => _key(TerminalKey.arrowRight),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keys that phone keyboards lack.
class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.onPressed, required this.label, this.icon});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    child: icon == null
        ? TextButton(onPressed: onPressed, child: Text(label))
        : IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon)),
  );
}
