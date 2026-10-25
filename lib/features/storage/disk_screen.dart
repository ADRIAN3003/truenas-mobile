import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/dialogs.dart';
import '../../shared/formatting.dart';
import '../../shared/glass.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import 'storage_helpers.dart';

/// One disk: its details, temperature, S.M.A.R.T. self-test log and a button
/// to start a self-test.
class DiskScreen extends StatefulWidget {
  const DiskScreen({super.key, required this.session, required this.disk});

  final TrueNasSession session;
  final Disk disk;

  @override
  State<DiskScreen> createState() => _DiskScreenState();
}

class _DiskScreenState extends State<DiskScreen> {
  late Disk _disk = widget.disk;
  SmartResults? _smart;
  Object? _smartError;
  bool _canRead = true;
  bool _canRun = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final storage = widget.session.storage;
    final temperatures = await storage.diskTemperatures();
    final canRead = await storage.canReadSmart();
    final canRun = await storage.canRunSmartTests();
    SmartResults? smart;
    Object? smartError;
    if (canRead) {
      try {
        smart = await storage.smartResults(_disk);
      } catch (error) {
        smartError = error;
      }
    }
    if (!mounted) return;
    setState(() {
      _disk = _disk.withTemperature(
        temperatures[_disk.name] ?? _disk.temperature,
      );
      _canRead = canRead;
      _canRun = canRun;
      _smart = smart;
      _smartError = smartError;
    });
    // Tests carry on in the disk, so follow a running one.
    _poll?.cancel();
    if (smart != null && smart.running) {
      _poll = Timer(const Duration(seconds: 10), _load);
    }
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAppChoice<SmartTestType>(
      context: context,
      title: l10n.diskSmartRunTitle,
      choices: [
        for (final type in SmartTestType.values)
          appChoice(
            type,
            '${_testName(l10n, type)} · ${_testHint(l10n, type)}',
          ),
      ],
    );
    if (picked == null || !mounted) return;
    final type = picked.$1;
    final started = await runWithFeedback(
      context,
      () => widget.session.storage.runSmartTest(_disk, type),
      success: l10n.diskSmartStarted(_testName(l10n, type), _disk.name),
    );
    if (!started || !mounted) return;
    // The disk takes a moment to report the test as running.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final disk = _disk;
    final temperature = disk.temperature;
    final kind = disk.isSsd
        ? l10n.diskSsd
        : disk.rotationRate != null
        ? l10n.diskRpm(disk.rotationRate!)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(disk.name)),
      body: AppRefreshIndicator(
        edgeOffset: ChromeInsets.of(context).top,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: ListTile(
                leading: IconTile(
                  disk.isSsd ? Icons.memory_rounded : Icons.album_rounded,
                  disk.isSsd ? AppPalette.tileTeal : AppPalette.tileSlate,
                  size: 40,
                ),
                title: Text(
                  [disk.name, formatBytes(disk.size), ?kind].join(' · '),
                ),
                subtitle: Text(
                  [
                    if (disk.model != null && disk.model!.isNotEmpty)
                      disk.model!,
                    if (disk.serial != null && disk.serial!.isNotEmpty)
                      l10n.diskSerial(disk.serial!),
                    disk.pool == null
                        ? l10n.diskUnused
                        : l10n.diskPool(disk.pool!),
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: temperature == null
                    ? null
                    : StatusPill(
                        label: l10n.cpuTemperature(
                          temperature.toStringAsFixed(0),
                        ),
                        tone: diskTemperatureTone(disk, temperature),
                      ),
              ),
            ),
            _smartCard(l10n),
            if (_smart != null && _smart!.tests.isNotEmpty) ...[
              SectionHeader(l10n.diskSmartHistory),
              GroupedCard(
                indent: 16,
                children: [
                  for (final test in _smart!.tests) _testTile(l10n, test),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _smartCard(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final smart = _smart;
    final Widget summary;
    if (!_canRead) {
      summary = Text(l10n.diskSmartUnavailable);
    } else if (_smartError != null) {
      summary = Text(describeConnectError(l10n, _smartError!));
    } else if (smart == null) {
      summary = const LinearProgressIndicator();
    } else if (smart.running) {
      summary = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(label: l10n.smartStatusRunning, tone: StatusTone.info),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: smart.progress == null ? null : smart.progress! / 100,
          ),
          if (smart.progress != null) ...[
            const SizedBox(height: 4),
            Text(l10n.diskSmartRunning(smart.progress!.toStringAsFixed(0))),
          ],
        ],
      );
    } else {
      final last = smart.lastFinished;
      summary = last == null
          ? Text(l10n.diskSmartNoTests)
          : Row(
              children: [
                StatusPill(
                  label: _statusLabel(l10n, last),
                  tone: _statusTone(last),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    last.passed
                        ? l10n.diskSmartLastPassed
                        : last.aborted
                        ? l10n.diskSmartLastAborted
                        : l10n.diskSmartLastFailed,
                  ),
                ),
              ],
            );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.diskSmartTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            summary,
            if (_canRead && !_disk.smartEnabled) ...[
              const SizedBox(height: 8),
              Text(
                l10n.diskSmartOff,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.of(context).muted,
                ),
              ),
            ],
            if (_canRun) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: smart != null && !smart.running ? _run : null,
                icon: const Icon(Icons.health_and_safety_rounded),
                label: Text(l10n.diskSmartRun),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _testTile(AppLocalizations l10n, SmartTest test) => ListTile(
    title: Text(test.description),
    subtitle: Text(
      [
        if (test.lifetime != null) l10n.diskSmartLifetime(test.lifetime!),
        if (test.lbaOfFirstError != null)
          l10n.diskSmartFirstError(test.lbaOfFirstError!),
        if (test.failed && test.statusVerbose != null) test.statusVerbose!,
      ].join('\n'),
    ),
    trailing: StatusPill(
      label: _statusLabel(l10n, test),
      tone: _statusTone(test),
    ),
  );
}

String _statusLabel(AppLocalizations l10n, SmartTest test) => test.passed
    ? l10n.smartStatusPassed
    : test.running
    ? l10n.smartStatusRunning
    : test.aborted
    ? l10n.smartStatusAborted
    : l10n.smartStatusFailed;

StatusTone _statusTone(SmartTest test) => test.passed
    ? StatusTone.good
    : test.running
    ? StatusTone.info
    : test.aborted
    ? StatusTone.warning
    : StatusTone.critical;

String _testName(AppLocalizations l10n, SmartTestType type) => switch (type) {
  SmartTestType.short => l10n.smartTestShort,
  SmartTestType.long => l10n.smartTestLong,
  SmartTestType.conveyance => l10n.smartTestConveyance,
  SmartTestType.offline => l10n.smartTestOffline,
};

String _testHint(AppLocalizations l10n, SmartTestType type) => switch (type) {
  SmartTestType.short => l10n.smartTestShortHint,
  SmartTestType.long => l10n.smartTestLongHint,
  SmartTestType.conveyance => l10n.smartTestConveyanceHint,
  SmartTestType.offline => l10n.smartTestOfflineHint,
};

/// How worrying [celsius] is for [disk]: spinning disks run cooler than
/// flash, so their limits are lower.
StatusTone diskTemperatureTone(Disk disk, double celsius) {
  final (warm, hot) = disk.isSsd ? (60, 70) : (45, 55);
  return celsius >= hot
      ? StatusTone.critical
      : celsius >= warm
      ? StatusTone.warning
      : StatusTone.good;
}
