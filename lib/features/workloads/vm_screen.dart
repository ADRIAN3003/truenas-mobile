import 'package:flutter/material.dart';

import '../../core/api/workloads_api.dart';
import '../../core/models/json.dart';
import '../../core/models/vm_config.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/dialogs.dart';
import '../../shared/formatting.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'vm_device_screen.dart';
import 'vm_edit_screen.dart';
import 'workload_widgets.dart';

typedef _Loaded = ({
  VirtualMachine? vm,
  List<VmDevice> devices,
  bool canEdit,
  bool canDelete,
});

/// One virtual machine: state and actions, its settings, and its devices
/// (disks, network adapters, display…), which can be added, changed and
/// removed.
class VmScreen extends StatefulWidget {
  const VmScreen({super.key, required this.session, required this.vm});

  final TrueNasSession session;
  final VirtualMachine vm;

  @override
  State<VmScreen> createState() => _VmScreenState();
}

class _VmScreenState extends State<VmScreen> with LoadState<VmScreen, _Loaded> {
  bool _busy = false;

  WorkloadsApi get _api => widget.session.workloads;

  @override
  Future<_Loaded> fetch() async {
    final (vm, canEdit, canDelete) = await (
      _api.vm(widget.vm.id),
      _api.canEditVm(),
      _api.canDeleteVm(),
    ).wait;
    final devices = canEdit && vm != null
        ? await _api.vmDevices(vm.id).catchError((_) => <VmDevice>[])
        : <VmDevice>[];
    if (vm == null && mounted) Navigator.pop(context);
    return (vm: vm, devices: devices, canEdit: canEdit, canDelete: canDelete);
  }

  Future<void> _run(VirtualMachine vm, WorkloadAction action) async {
    final ok = await runWorkloadAction(
      context,
      name: vm.name,
      action: action,
      isVm: true,
      run: () => _api.vmAction(vm.id, action),
      onConfirmed: () => setState(() => _busy = true),
    );
    if (!mounted) return;
    if (ok || _busy) await load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit(VirtualMachine vm) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => VmEditScreen(session: widget.session, vm: vm),
      ),
    );
    if (saved == true) await load();
  }

  Future<void> _delete(VirtualMachine vm) async {
    final l10n = AppLocalizations.of(context);
    final destroyDisks = ValueNotifier(false);
    final confirmed = await confirmAction(
      context,
      title: l10n.vmDeleteTitle(vm.name),
      body: l10n.vmDeleteBody,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.cancel,
      typeToConfirm: vm.name,
      typeToConfirmHint: l10n.typeNameToConfirm(vm.name),
      destructive: true,
      details: ValueListenableBuilder<bool>(
        valueListenable: destroyDisks,
        builder: (context, value, _) => AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmDeleteDisks),
          value: value,
          onChanged: (v) => destroyDisks.value = v,
        ),
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => _api.deleteVm(vm.id, removeZvols: destroyDisks.value),
      success: l10n.actionDeleted(vm.name),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _addDevice(VirtualMachine vm) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAppChoice<VmDeviceType>(
      context: context,
      title: l10n.vmDeviceAdd,
      dialogOnAndroid: true,
      choices: [
        for (final t in VmDeviceType.values)
          appChoice(
            t,
            vmDeviceTypeLabel(l10n, t.value),
            leading: Icon(vmDeviceIcon(t.value)),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    await _openDevice(vm, type: picked.$1);
  }

  Future<void> _openDevice(
    VirtualMachine vm, {
    VmDevice? device,
    VmDeviceType? type,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => VmDeviceScreen(
          session: widget.session,
          vmId: vm.id,
          vmName: vm.name,
          device: device,
          type: type,
        ),
      ),
    );
    if (saved == true) await load();
  }

  Future<void> _removeDevice(VmDevice device) async {
    final l10n = AppLocalizations.of(context);
    final path = (device.attributes['path'] ?? '').toString();
    final isZvol = device.type == VmDeviceType.disk && path.startsWith('/dev/');
    final destroy = ValueNotifier(false);
    final confirmed = await confirmAction(
      context,
      title: l10n.vmDeviceRemoveTitle(vmDeviceTypeLabel(l10n, device.dtype)),
      body: l10n.vmDeviceRemoveBody,
      confirmLabel: l10n.vmDeviceRemove,
      cancelLabel: l10n.cancel,
      destructive: true,
      details: isZvol
          ? ValueListenableBuilder<bool>(
              valueListenable: destroy,
              builder: (context, value, _) => AppSwitchTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.vmDeviceDestroyZvol),
                subtitle: Text(path),
                value: value,
                onChanged: (v) => destroy.value = v,
              ),
            )
          : null,
    );
    if (!confirmed || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => _api.deleteVmDevice(device.id, removeZvol: destroy.value),
      success: l10n.vmDeviceRemoved,
    );
    if (ok && mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loaded = data;
    final vm = loaded?.vm ?? widget.vm;
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.name),
        actions: [
          if (loaded?.canEdit ?? false)
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : () => _edit(vm),
            ),
          if (loaded?.canDelete ?? false)
            IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : () => _delete(vm),
            ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _summary(context, vm),
            if (loaded != null)
              ..._details(context, vm, loaded)
            else if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(
                      describeConnectError(l10n, error!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() => error = null);
                        load();
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, VirtualMachine vm) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actions = actionsFor(vm.state, supported: vmActions);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconTile(
                  Icons.computer_rounded,
                  AppPalette.tilePurple,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(vm.name, style: theme.textTheme.titleMedium),
                ),
                WorkloadStateLabel(state: vm.state),
              ],
            ),
            if (vm.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(vm.description),
            ],
            const SizedBox(height: 12),
            if (_busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    OutlinedButton(
                      onPressed: () => _run(vm, action),
                      child: Text(actionLabel(l10n, action)),
                    ),
                  if (vm.state == WorkloadState.running)
                    OutlinedButton.icon(
                      onPressed: () => openShell(
                        context,
                        widget.session,
                        WorkloadsApi.vmShell(vm.id),
                        vm.name,
                      ),
                      icon: const Icon(Icons.terminal),
                      label: Text(l10n.shellTitle),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(
    BuildContext context,
    VirtualMachine vm,
    _Loaded loaded,
  ) {
    final l10n = AppLocalizations.of(context);
    final raw = vm.raw;
    final cpu =
        '${raw['vcpus'] ?? 1} × ${raw['cores'] ?? 1} × '
        '${raw['threads'] ?? 1}';
    return [
      SectionHeader(l10n.vmSectionSettings),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              InfoRow(l10n.vmInfoCpu, l10n.vmInfoCpuValue(vm.vcpus, cpu)),
              InfoRow(
                l10n.vmInfoMemory,
                formatBytes(vm.memoryMib * 1024 * 1024),
              ),
              if (raw['bootloader'] != null)
                InfoRow(l10n.vmBootloader, raw['bootloader'].toString()),
              InfoRow(l10n.vmAutostartField, vm.autostart ? '✓' : '–'),
              if (raw['shutdown_timeout'] != null)
                InfoRow(
                  l10n.vmShutdownTimeout,
                  l10n.vmSeconds(asInt(raw['shutdown_timeout'])),
                ),
            ],
          ),
        ),
      ),
      if (loaded.canEdit)
        ...groupedSection(
          l10n.vmDevices,
          empty: l10n.vmDevicesEmpty,
          indent: 72,
          trailing: IconButton(
            tooltip: l10n.vmDeviceAdd,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _addDevice(vm),
          ),
          [
            for (final device in loaded.devices)
              ListTile(
                leading: IconTile(
                  vmDeviceIcon(device.dtype),
                  AppPalette.tileBlue,
                  size: 40,
                ),
                title: Text(vmDeviceTypeLabel(l10n, device.dtype)),
                subtitle: device.detail.isEmpty ? null : Text(device.detail),
                trailing: AppPopupMenu<String>(
                  entries: [
                    menuEntry('edit', l10n.edit),
                    menuEntry('remove', l10n.vmDeviceRemove, destructive: true),
                  ],
                  onSelected: (action) => action == 'edit'
                      ? _openDevice(vm, device: device)
                      : _removeDevice(device),
                ),
                onTap: () => _openDevice(vm, device: device),
              ),
          ],
        ),
    ];
  }
}
