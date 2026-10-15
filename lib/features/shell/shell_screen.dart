import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/api/shell_session.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';

/// A terminal on the server, like System → Shell in the web UI.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    required this.session,
    this.options = const {},
    this.title,
  });

  final TrueNasSession session;

  /// Picks a VM, app or container console instead of the host shell.
  final Map<String, Object?> options;
  final String? title;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

enum _Status { connecting, connected, closed }

class _ShellScreenState extends State<ShellScreen> {
  final _terminal = Terminal(maxLines: 10000);
  final _focus = FocusNode();
  ShellSession? _shell;
  StreamSubscription<String>? _output;
  _Status _status = _Status.connecting;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) => _shell?.write(data);
    _terminal.onResize = (cols, rows, _, _) => _shell?.resize(cols, rows);
    _connect();
  }

  @override
  void dispose() {
    _output?.cancel();
    _shell?.close();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _status = _Status.connecting;
      _error = null;
    });
    try {
      final shell = await widget.session.openShell(options: widget.options);
      if (!mounted) {
        await shell.close();
        return;
      }
      _shell = shell;
      _output = shell.output
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            _terminal.write,
            onDone: () {
              if (mounted) setState(() => _status = _Status.closed);
            },
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

  Future<void> _restart() async {
    await _output?.cancel();
    await _shell?.close();
    _shell = null;
    _terminal.write('\r\n');
    await _connect();
  }

  void _key(TerminalKey key, {bool ctrl = false}) {
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
                      icon: Icons.keyboard_arrow_up,
                      onPressed: () => _key(TerminalKey.arrowUp),
                    ),
                    _KeyButton(
                      icon: Icons.keyboard_arrow_down,
                      onPressed: () => _key(TerminalKey.arrowDown),
                    ),
                    _KeyButton(
                      icon: Icons.keyboard_arrow_left,
                      onPressed: () => _key(TerminalKey.arrowLeft),
                    ),
                    _KeyButton(
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
  const _KeyButton({required this.onPressed, this.label, this.icon});

  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    child: icon == null
        ? TextButton(onPressed: onPressed, child: Text(label!))
        : IconButton(onPressed: onPressed, icon: Icon(icon)),
  );
}
