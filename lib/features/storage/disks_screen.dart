import 'package:flutter/material.dart';

import '../../core/models/storage.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/formatting.dart';
import 'storage_helpers.dart';

/// All disks with size, model, pool and temperature.
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
            : ListView.separated(
                itemCount: disks.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final disk = disks[index];
                  final temperature = disk.temperature;
                  final kind = disk.isSsd
                      ? l10n.diskSsd
                      : disk.rotationRate != null
                      ? l10n.diskRpm(disk.rotationRate!)
                      : null;
                  return ListTile(
                    leading: Icon(
                      disk.isSsd ? Icons.memory : Icons.album_outlined,
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
                        : Text(
                            l10n.cpuTemperature(temperature.toStringAsFixed(0)),
                          ),
                  );
                },
              ),
      ),
    );
  }
}
