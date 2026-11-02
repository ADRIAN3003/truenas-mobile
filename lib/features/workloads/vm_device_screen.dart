import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/json.dart';
import '../../core/models/vm_config.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'vm_form_fields.dart';

/// The localized name of a device kind. Kinds the app doesn't know by name
/// show the server's own word.
String vmDeviceTypeLabel(AppLocalizations l10n, String dtype) =>
    switch (VmDeviceType.parse(dtype)) {
      VmDeviceType.disk => l10n.vmDeviceDisk,
      VmDeviceType.raw => l10n.vmDeviceRaw,
      VmDeviceType.cdrom => l10n.vmDeviceCdrom,
      VmDeviceType.nic => l10n.vmDeviceNic,
      VmDeviceType.display => l10n.vmDeviceDisplay,
      VmDeviceType.pci => l10n.vmDevicePci,
      VmDeviceType.usb => l10n.vmDeviceUsb,
      null => dtype,
    };

IconData vmDeviceIcon(String dtype) => switch (VmDeviceType.parse(dtype)) {
  VmDeviceType.disk => Icons.storage_rounded,
  VmDeviceType.raw => Icons.insert_drive_file_outlined,
  VmDeviceType.cdrom => Icons.album_outlined,
  VmDeviceType.nic => Icons.lan_outlined,
  VmDeviceType.display => Icons.desktop_windows_outlined,
  VmDeviceType.pci => Icons.memory_rounded,
  VmDeviceType.usb => Icons.usb_rounded,
  null => Icons.extension_outlined,
};

typedef _Options = ({VmChoices choices, List<String> pools});

/// Adds a [type] device to a virtual machine, or edits [device]. Pops `true`
/// once the server has taken it.
class VmDeviceScreen extends StatefulWidget {
  const VmDeviceScreen({
    super.key,
    required this.session,
    required this.vmId,
    required this.vmName,
    this.device,
    this.type,
  }) : assert(device != null || type != null);

  final TrueNasSession session;
  final int vmId;
  final String vmName;
  final VmDevice? device;

  /// The kind to add when [device] is null.
  final VmDeviceType? type;

  @override
  State<VmDeviceScreen> createState() => _VmDeviceScreenState();
}

class _VmDeviceScreenState extends State<VmDeviceScreen>
    with LoadState<VmDeviceScreen, _Options> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final String _dtype = widget.device?.dtype ?? widget.type!.value;
  late final VmDeviceType? _kind = VmDeviceType.parse(_dtype);
  late final Map<String, dynamic> _attrs = {...?widget.device?.attributes};

  bool get _creating => widget.device == null;

  // Text fields, by the attribute they edit.
  final _path = TextEditingController();
  final _mac = TextEditingController();
  final _password = TextEditingController();
  final _pptdev = TextEditingController();
  final _usbDevice = TextEditingController();
  final _usbController = TextEditingController();
  final _zvolSize = TextEditingController(text: '20');
  final _zvolName = TextEditingController();
  late final _json = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert(_attrs),
  );

  String _bus = 'VIRTIO';
  String _nicType = 'VIRTIO';
  String? _attach;
  String? _resolution;
  String? _bind;
  bool _web = true;
  bool _trustRx = false;
  bool _newZvol = true;
  String? _pool;

  @override
  void initState() {
    final a = _attrs;
    String text(String key) => (a[key] ?? '').toString();
    _path.text = text('path');
    _mac.text = text('mac');
    _password.text = text('password');
    _pptdev.text = text('pptdev');
    _usbDevice.text = text('device');
    _usbController.text = a['controller_type']?.toString() ?? 'nec-xhci';
    _bus = a['type']?.toString() == 'AHCI' ? 'AHCI' : 'VIRTIO';
    _nicType = a['type']?.toString() ?? 'VIRTIO';
    _attach = a['nic_attach'] as String?;
    _resolution = a['resolution'] as String? ?? '1024x768';
    _bind = a['bind'] as String? ?? '0.0.0.0';
    _web = a['web'] != false;
    _trustRx = a['trust_guest_rx_filters'] == true;
    _newZvol = _creating;
    super.initState();
  }

  @override
  Future<_Options> fetch() async {
    final api = widget.session.workloads;
    final needsPools = _creating && _kind == VmDeviceType.disk;
    final (choices, pools) = await (
      api.vmChoices(),
      needsPools
          ? widget.session.storage.pools().then(
              (list) => [for (final p in list) p.name],
              onError: (_) => <String>[],
            )
          : Future.value(<String>[]),
    ).wait;
    _pool ??= pools.firstOrNull;
    if (_creating && _kind == VmDeviceType.nic) {
      _attach ??= choices.nicAttach.keys.firstOrNull;
    }
    return (choices: choices, pools: pools);
  }

  @override
  void dispose() {
    for (final c in [
      _path,
      _mac,
      _password,
      _pptdev,
      _usbDevice,
      _usbController,
      _zvolSize,
      _zvolName,
      _json,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The full attribute set to send: what the device had, with the edited
  /// fields on top, since the server replaces the whole set.
  Map<String, dynamic>? _collect() {
    final l10n = AppLocalizations.of(context);
    final a = {..._attrs};
    switch (_kind) {
      case VmDeviceType.disk:
        a['type'] = _bus;
        final pool = _pool;
        if (_creating && _newZvol && pool != null) {
          final name = _zvolName.text.trim().isEmpty
              ? newZvolName(pool, widget.vmName, 1)
              : '$pool/${_zvolName.text.trim()}';
          a
            ..['create_zvol'] = true
            ..['zvol_name'] = name
            ..['zvol_volsize'] = gibToBytes(
              int.tryParse(_zvolSize.text.trim()) ?? 20,
            )
            ..remove('path');
        } else if (_path.text.trim().isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.validationRequired)));
          return null;
        } else {
          a['path'] = _path.text.trim();
        }
      case VmDeviceType.raw:
        a
          ..['path'] = _path.text.trim()
          ..['type'] = _bus
          ..putIfAbsent('exists', () => true);
      case VmDeviceType.cdrom:
        a['path'] = _path.text.trim();
      case VmDeviceType.nic:
        a
          ..['type'] = _nicType
          ..['trust_guest_rx_filters'] = _trustRx;
        if (_attach != null) a['nic_attach'] = _attach;
        if (_mac.text.trim().isNotEmpty) {
          a['mac'] = _mac.text.trim();
        } else {
          a.remove('mac');
        }
      case VmDeviceType.display:
        a
          ..putIfAbsent('type', () => 'SPICE')
          ..['resolution'] = _resolution
          ..['bind'] = _bind
          ..['web'] = _web
          ..['password'] = _password.text;
      case VmDeviceType.pci:
        a['pptdev'] = _pptdev.text.trim();
      case VmDeviceType.usb:
        a['controller_type'] = _usbController.text.trim();
        if (_usbDevice.text.trim().isEmpty) {
          a['device'] = null;
        } else {
          a['device'] = _usbDevice.text.trim();
        }
      case null:
        try {
          return asMap(jsonDecode(_json.text));
        } catch (_) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.vmDeviceJsonInvalid)));
          return null;
        }
    }
    return a..['dtype'] = _dtype;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final attributes = _collect();
    if (attributes == null) return;
    final l10n = AppLocalizations.of(context);
    final api = widget.session.workloads;
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => _creating
          ? api.createVmDevice(widget.vmId, _dtype, attributes)
          : api.updateVmDevice(widget.device!.id, attributes),
      success: l10n.vmDeviceSaved,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _randomMac() async {
    final mac = await widget.session.workloads.randomMac();
    if (mac != null && mounted) setState(() => _mac.text = mac);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = vmDeviceTypeLabel(l10n, _dtype);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _creating
              ? l10n.vmDeviceAddTitle(label)
              : l10n.vmDeviceEditTitle(label),
        ),
        actions: [
          TextButton(
            onPressed: data == null || _saving ? null : _save,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_saving) const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.vmDeviceNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      for (final field in _fields(context, options))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: field,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(BuildContext context, _Options options) {
    final l10n = AppLocalizations.of(context);
    final choices = options.choices;
    const buses = {'VIRTIO': 'VirtIO', 'AHCI': 'AHCI'};
    return switch (_kind) {
      VmDeviceType.disk => [
        vmChoiceField(
          label: l10n.vmDeviceBus,
          value: _bus,
          options: buses,
          helper: l10n.vmDeviceBusHelp,
          onChanged: (v) => setState(() => _bus = v ?? 'VIRTIO'),
        ),
        if (_creating && options.pools.isNotEmpty)
          AppSegments<bool>(
            values: const [true, false],
            labels: [l10n.vmDeviceNewZvol, l10n.vmDeviceExistingZvol],
            selected: _newZvol,
            onChanged: (v) => setState(() => _newZvol = v),
          ),
        if (_creating && _newZvol && options.pools.isNotEmpty) ...[
          vmChoiceField(
            label: l10n.vmDevicePool,
            value: _pool,
            options: {for (final p in options.pools) p: p},
            onChanged: (v) => setState(() => _pool = v),
          ),
          vmTextField(
            context,
            controller: _zvolName,
            label: l10n.vmDeviceZvolName,
            helper: l10n.vmDeviceZvolNameHelp,
            required: false,
          ),
          vmNumberField(
            context,
            controller: _zvolSize,
            label: l10n.vmDeviceSizeGib,
          ),
        ] else if (choices.disks.isNotEmpty)
          vmChoiceField(
            label: l10n.vmDeviceZvol,
            value: _path.text.isEmpty ? null : _path.text,
            options: choices.disks,
            onChanged: (v) => setState(() => _path.text = v ?? ''),
          )
        else
          vmTextField(
            context,
            controller: _path,
            label: l10n.vmDevicePath,
            helper: l10n.vmDeviceZvolPathHelp,
          ),
      ],
      VmDeviceType.raw => [
        vmTextField(
          context,
          controller: _path,
          label: l10n.vmDevicePath,
          helper: l10n.vmDeviceRawPathHelp,
        ),
        vmChoiceField(
          label: l10n.vmDeviceBus,
          value: _bus,
          options: buses,
          onChanged: (v) => setState(() => _bus = v ?? 'VIRTIO'),
        ),
      ],
      VmDeviceType.cdrom => [
        vmTextField(
          context,
          controller: _path,
          label: l10n.vmDevicePath,
          helper: l10n.vmDeviceCdromPathHelp,
        ),
      ],
      VmDeviceType.nic => [
        vmChoiceField(
          label: l10n.vmNicType,
          value: _nicType,
          options: const {'VIRTIO': 'VirtIO', 'E1000': 'Intel e82545 (E1000)'},
          helper: l10n.vmNicTypeHelp,
          onChanged: (v) => setState(() => _nicType = v ?? 'VIRTIO'),
        ),
        if (choices.nicAttach.isNotEmpty)
          vmChoiceField(
            label: l10n.vmNicAttach,
            value: _attach,
            options: choices.nicAttach,
            onChanged: (v) => setState(() => _attach = v),
          )
        else
          TextFormField(
            initialValue: _attach,
            autocorrect: false,
            decoration: InputDecoration(labelText: l10n.vmNicAttach),
            onChanged: (v) => _attach = v.trim().isEmpty ? null : v.trim(),
          ),
        vmTextField(
          context,
          controller: _mac,
          label: l10n.vmMac,
          helper: l10n.vmMacHelp,
          required: false,
          suffix: IconButton(
            tooltip: l10n.vmMacRandom,
            icon: const Icon(Icons.casino_outlined),
            onPressed: _randomMac,
          ),
        ),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmTrustRx),
          subtitle: Text(l10n.vmTrustRxHelp),
          value: _trustRx,
          onChanged: (v) => setState(() => _trustRx = v),
        ),
      ],
      VmDeviceType.display => [
        if (choices.resolutions.isNotEmpty)
          vmChoiceField(
            label: l10n.vmResolution,
            value: _resolution,
            options: {for (final r in choices.resolutions) r: r},
            onChanged: (v) => setState(() => _resolution = v),
          ),
        if (choices.binds.isNotEmpty)
          vmChoiceField(
            label: l10n.vmBind,
            value: _bind,
            options: choices.binds,
            onChanged: (v) => setState(() => _bind = v),
          ),
        vmTextField(
          context,
          controller: _password,
          label: l10n.vmDisplayPassword,
          obscure: true,
          required: false,
        ),
        AppSwitchTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.vmDisplayWeb),
          subtitle: Text(l10n.vmDisplayWebHelp),
          value: _web,
          onChanged: (v) => setState(() => _web = v),
        ),
      ],
      VmDeviceType.pci => [
        vmTextField(
          context,
          controller: _pptdev,
          label: l10n.vmPciDevice,
          helper: l10n.vmPciDeviceHelp,
        ),
      ],
      VmDeviceType.usb => [
        vmTextField(
          context,
          controller: _usbController,
          label: l10n.vmUsbController,
        ),
        vmTextField(
          context,
          controller: _usbDevice,
          label: l10n.vmUsbDevice,
          required: false,
        ),
      ],
      null => [
        TextFormField(
          controller: _json,
          minLines: 6,
          maxLines: 16,
          autocorrect: false,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(labelText: l10n.vmDeviceJson),
        ),
      ],
    };
  }
}
