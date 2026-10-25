import 'package:flutter/material.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/formatting.dart';
import 'disk_screen.dart';
import 'storage_helpers.dart';

/// All disks with size, model, pool and temperature; a tap opens the disk's
/// S.M.A.R.T. results.
class DisksScreen extends StatefulWidget {
  const DisksScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<DisksScreen> createState() => _DisksScreenState();
}

class _DisksScreenState extends State<DisksScreen> {
  List<Disk>? _disks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final disks = await widget.session.storage.disks();
      if (!mounted) return;
      setState(() {
        _disks = disks;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.disksTitle)),
      body: AsyncBody<List<Disk>>(
        value: _disks,
        error: _error,
        onRefresh: _load,
        builder: (disks) => disks.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.disksEmpty)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GroupedCard(
                    indent: 72,
                    children: [for (final disk in disks) _tile(l10n, disk)],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _tile(AppLocalizations l10n, Disk disk) {
    final temperature = disk.temperature;
    final kind = disk.isSsd
        ? l10n.diskSsd
        : disk.rotationRate != null
        ? l10n.diskRpm(disk.rotationRate!)
        : null;
    return ListTile(
      leading: IconTile(
        disk.isSsd ? Icons.memory_rounded : Icons.album_rounded,
        disk.isSsd ? AppPalette.tileTeal : AppPalette.tileSlate,
        size: 40,
      ),
      title: Text([disk.name, formatBytes(disk.size), ?kind].join(' · ')),
      subtitle: Text(
        [
          if (disk.model != null && disk.model!.isNotEmpty) disk.model!,
          if (disk.serial != null && disk.serial!.isNotEmpty)
            l10n.diskSerial(disk.serial!),
          disk.pool == null ? l10n.diskUnused : l10n.diskPool(disk.pool!),
        ].join('\n'),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (temperature != null)
            Text(l10n.cpuTemperature(temperature.toStringAsFixed(0))),
          const SizedBox(width: 4),
          const Chevron(),
        ],
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DiskScreen(session: widget.session, disk: disk),
          ),
        );
        _load();
      },
    );
  }
}
