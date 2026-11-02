import 'package:flutter/material.dart';

import '../../core/models/vm_config.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'vm_form_fields.dart';

typedef _Options = ({VmChoices choices, List<String> pools});

/// Creates a virtual machine, or edits [vm]'s settings (name, processor,
/// memory, boot and clock). A new machine can get a disk, a network adapter
/// and an install image in the same step; devices are changed from the
/// machine's own screen afterwards. Pops `true` once the server has taken it.
class VmEditScreen extends StatefulWidget {
  const VmEditScreen({super.key, required this.session, this.vm});

  final TrueNasSession session;
  final VirtualMachine? vm;

  @override
  State<VmEditScreen> createState() => _VmEditScreenState();
}

class _VmEditScreenState extends State<VmEditScreen>
    with LoadState<VmEditScreen, _Options> {
  final _formKey = GlobalKey<FormState>();
  late final VmDraft _draft = widget.vm == null
      ? VmDraft()
      : VmDraft.fromJson(widget.vm!.raw);
  late final _name = TextEditingController(text: _draft.name);
  late final _description = TextEditingController(text: _draft.description);
  late final _vcpus = TextEditingController(text: '${_draft.vcpus}');
  late final _cores = TextEditingController(text: '${_draft.cores}');
  late final _threads = TextEditingController(text: '${_draft.threads}');
  late final _memory = TextEditingController(text: '${_draft.memory}');
  late final _minMemory = TextEditingController(
    text: _draft.minMemory?.toString() ?? '',
  );
  late final _shutdown = TextEditingController(
    text: '${_draft.shutdownTimeout}',
  );

  // Only for a new machine.
  bool _addDisk = true;
  String? _pool;
  final _diskSize = TextEditingController(text: '20');
  String _diskBus = 'VIRTIO';
  bool _addNic = true;
  String? _attach;
  final _iso = TextEditingController();

  bool _saving = false;

  bool get _creating => widget.vm == null;

  @override
  Future<_Options> fetch() async {
    final api = widget.session.workloads;
    final (choices, pools) = await (
      api.vmChoices(),
      _creating
          ? widget.session.storage.pools().then(
              (list) => [for (final p in list) p.name],
              onError: (_) => <String>[],
            )
          : Future.value(<String>[]),
    ).wait;
    _pool ??= pools.firstOrNull;
    _attach ??= choices.nicAttach.keys.firstOrNull;
    if (_creating) {
      final defaults = choices.bootloaders;
      if (defaults.isNotEmpty && !defaults.containsKey(_draft.bootloader)) {
        _draft.bootloader = defaults.keys.first;
      }
    }
    return (choices: choices, pools: pools);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _vcpus,
      _cores,
      _threads,
      _memory,
      _minMemory,
      _shutdown,
      _diskSize,
      _iso,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  Future<void> _save(_Options options) async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    _draft
      ..name = _name.text.trim()
      ..description = _description.text.trim()
      ..vcpus = _int(_vcpus, 1)
      ..cores = _int(_cores, 1)
      ..threads = _int(_threads, 1)
      ..memory = _int(_memory, 2048)
      ..minMemory = int.tryParse(_minMemory.text.trim())
      ..shutdownTimeout = _int(_shutdown, 90);
    final api = widget.session.workloads;
    final devices = <Map<String, dynamic>>[
      if (_creating && _addDisk && _pool != null)
        {
          'attributes': {
            'dtype': VmDeviceType.disk.value,
            'type': _diskBus,
            'create_zvol': true,
            'zvol_name': newZvolName(_pool!, _draft.name, 0),
            'zvol_volsize': gibToBytes(_int(_diskSize, 20)),
          },
        },
      if (_creating && _iso.text.trim().isNotEmpty)
        {
          'attributes': {
            'dtype': VmDeviceType.cdrom.value,
            'path': _iso.text.trim(),
          },
        },
      if (_creating && _addNic)
        {
          'attributes': {
            'dtype': VmDeviceType.nic.value,
            'type': 'VIRTIO',
            'nic_attach': ?_attach,
          },
        },
    ];
    setState(() => _saving = true);
    final name = _draft.name;
    final ok = await runWithFeedback(
      context,
      () => _creating
          ? api.createVm(_draft.toPayload(), devices)
          : api.updateVm(widget.vm!.id, _draft.changesFrom(widget.vm!.raw)),
      success: _creating ? l10n.vmCreated(name) : l10n.vmSaved(name),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _creating ? l10n.vmCreateTitle : l10n.vmEditTitle(widget.vm!.name),
        ),
        actions: [
          TextButton(
            onPressed: data == null || _saving ? null : () => _save(data!),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: AsyncBody<_Options>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (options) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _fields(context, options),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fields(BuildContext context, _Options options) {
    final l10n = AppLocalizations.of(context);
    final choices = options.choices;
    final d = _draft;
    final cpuModels = choices.cpuModels;
    final max = choices.maxVcpus;
    final bootloaders = choices.bootloaders.isEmpty
        ? const {'UEFI': 'UEFI', 'UEFI_CSM': 'UEFI-CSM'}
        : choices.bootloaders;

    Widget gap(Widget child) =>
        Padding(padding: const EdgeInsets.only(top: 12), child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saving) const LinearProgressIndicator(),
        if (!_creating)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.vmEditNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SectionHeader(l10n.vmSectionGeneral),
        gap(vmTextField(context, controller: _name, label: l10n.vmName)),
        gap(
          vmTextField(
            context,
            controller: _description,
            label: l10n.vmDescription,
            required: false,
          ),
        ),
        SectionHeader(l10n.vmSectionProcessor),
        gap(
          vmNumberField(
            context,
            controller: _vcpus,
            label: l10n.vmVcpusField,
            helper: max == null ? null : l10n.vmVcpusMax(max),
          ),
        ),
        gap(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: vmNumberField(
                  context,
                  controller: _cores,
                  label: l10n.vmCoresField,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: vmNumberField(
                  context,
                  controller: _threads,
                  label: l10n.vmThreadsField,
                ),
              ),
            ],
          ),
        ),
        gap(
          vmChoiceField(
            label: l10n.vmCpuMode,
            value: d.cpuMode,
            options: {
              'CUSTOM': l10n.vmCpuModeCustom,
              'HOST-MODEL': l10n.vmCpuModeHostModel,
              'HOST-PASSTHROUGH': l10n.vmCpuModeHostPassthrough,
            },
            onChanged: (v) => setState(() => d.cpuMode = v ?? 'CUSTOM'),
          ),
        ),
        if (d.cpuMode == 'CUSTOM' && cpuModels.isNotEmpty)
          gap(
            vmChoiceField(
              label: l10n.vmCpuModel,
              value: d.cpuModel,
              options: cpuModels,
              noneLabel: l10n.vmCpuModelDefault,
              onChanged: (v) => setState(() => d.cpuModel = v),
            ),
          ),
        gap(
          vmNumberField(
            context,
            controller: _memory,
            label: l10n.vmMemoryField,
            min: 256,
          ),
        ),
        gap(
          vmNumberField(
            context,
            controller: _minMemory,
            label: l10n.vmMinMemoryField,
            helper: l10n.vmMinMemoryHelp,
            min: 256,
            optional: true,
          ),
        ),
        SectionHeader(l10n.vmSectionBoot),
        gap(
          vmChoiceField(
            label: l10n.vmBootloader,
            value: d.bootloader,
            options: bootloaders,
            onChanged: (v) => setState(() => d.bootloader = v ?? 'UEFI'),
          ),
        ),
        gap(
          vmChoiceField(
            label: l10n.vmClock,
            value: d.time,
            options: {'LOCAL': l10n.vmClockLocal, 'UTC': 'UTC'},
            onChanged: (v) => setState(() => d.time = v ?? 'LOCAL'),
          ),
        ),
        gap(
          vmNumberField(
            context,
            controller: _shutdown,
            label: l10n.vmShutdownTimeout,
            helper: l10n.vmShutdownTimeoutHelp,
          ),
        ),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmAutostartField),
          value: d.autostart,
          onChanged: (v) => setState(() => d.autostart = v),
        ),
        SectionHeader(l10n.vmSectionAdvanced),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmEnsureDisplay),
          subtitle: Text(l10n.vmEnsureDisplayHelp),
          value: d.ensureDisplayDevice,
          onChanged: (v) => setState(() => d.ensureDisplayDevice = v),
        ),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmHyperv),
          subtitle: Text(l10n.vmHypervHelp),
          value: d.hypervEnlightenments,
          onChanged: (v) => setState(() => d.hypervEnlightenments = v),
        ),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmHideFromMsr),
          subtitle: Text(l10n.vmHideFromMsrHelp),
          value: d.hideFromMsr,
          onChanged: (v) => setState(() => d.hideFromMsr = v),
        ),
        if (d.trustedPlatformModule case final tpm?)
          AppSwitchTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vmTpm),
            value: tpm,
            onChanged: (v) => setState(() => d.trustedPlatformModule = v),
          ),
        if (_creating) ..._newDevices(context, options),
      ],
    );
  }

  /// Disk, network and install image for a new machine.
  List<Widget> _newDevices(BuildContext context, _Options options) {
    final l10n = AppLocalizations.of(context);
    final nic = options.choices.nicAttach;
    return [
      SectionHeader(l10n.vmSectionNewDevices),
      if (options.pools.isNotEmpty)
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmNewDisk),
          value: _addDisk,
          onChanged: (v) => setState(() => _addDisk = v),
        ),
      if (_addDisk && options.pools.isNotEmpty) ...[
        const SizedBox(height: 8),
        vmChoiceField(
          label: l10n.vmDevicePool,
          value: _pool,
          options: {for (final p in options.pools) p: p},
          onChanged: (v) => setState(() => _pool = v),
        ),
        const SizedBox(height: 12),
        vmNumberField(
          context,
          controller: _diskSize,
          label: l10n.vmDeviceSizeGib,
        ),
        const SizedBox(height: 12),
        vmChoiceField(
          label: l10n.vmDeviceBus,
          value: _diskBus,
          options: const {'VIRTIO': 'VirtIO', 'AHCI': 'AHCI'},
          helper: l10n.vmDeviceBusHelp,
          onChanged: (v) => setState(() => _diskBus = v ?? 'VIRTIO'),
        ),
      ],
      if (nic.isNotEmpty) ...[
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmNewNic),
          value: _addNic,
          onChanged: (v) => setState(() => _addNic = v),
        ),
        if (_addNic) ...[
          const SizedBox(height: 8),
          vmChoiceField(
            label: l10n.vmNicAttach,
            value: _attach,
            options: nic,
            onChanged: (v) => setState(() => _attach = v),
          ),
        ],
      ],
      const SizedBox(height: 12),
      vmTextField(
        context,
        controller: _iso,
        label: l10n.vmInstallImage,
        helper: l10n.vmInstallImageHelp,
        required: false,
      ),
    ];
  }
}
