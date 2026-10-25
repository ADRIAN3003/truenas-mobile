import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_address.dart';
import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/models/system.dart';
import '../../core/session/truenas_session.dart';
import '../../core/wol/wake_on_lan.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/dialogs.dart';
import '../../shared/ui.dart';

/// Adds a new server, or edits [instance] when given.
class ServerFormScreen extends ConsumerStatefulWidget {
  const ServerFormScreen({super.key, this.instance});

  final ServerInstance? instance;

  @override
  ConsumerState<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends ConsumerState<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.instance?.name);
  late final _url = TextEditingController(text: widget.instance?.url);
  late final _username = TextEditingController(
    text: widget.instance?.username ?? 'truenas_admin',
  );
  late final _wolMac = TextEditingController(text: widget.instance?.wol?.mac);
  late final _wolBroadcast = TextEditingController(
    text: _wolText(widget.instance?.wol?.broadcast, defaultWolBroadcast),
  );
  late final _wolPort = TextEditingController(
    text: _wolText(widget.instance?.wol?.port, defaultWolPort),
  );
  // The saved password or key is never shown, so the field starts empty.
  final _secret = TextEditingController();
  late AuthMethod _authMethod =
      widget.instance?.authMethod ?? AuthMethod.apiKey;
  late String? _pinnedFingerprint = widget.instance?.pinnedFingerprint;
  late String? _lastApiVersion = widget.instance?.lastApiVersion;
  late final String _id = widget.instance?.id ?? newInstanceId();
  var _obscure = true;
  var _testing = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _url,
      _username,
      _secret,
      _wolMac,
      _wolBroadcast,
      _wolPort,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whether an empty secret field keeps the saved one: when editing, as long
  /// as the sign-in method is still the one the secret belongs to.
  bool get _keepsSavedSecret =>
      widget.instance != null && widget.instance!.authMethod == _authMethod;

  ServerInstance _build() {
    final address = ServerAddress.tryParse(_url.text)!;
    final name = _name.text.trim();
    return ServerInstance(
      id: _id,
      name: name.isEmpty ? address.uri.host : name,
      url: address.toString(),
      authMethod: _authMethod,
      username: _username.text.trim(),
      secret: _secret.text.trim().isEmpty && _keepsSavedSecret
          ? widget.instance!.secret
          : _secret.text.trim(),
      pinnedFingerprint: _pinnedFingerprint,
      lastApiVersion: _lastApiVersion,
      wol: _wolSettings(),
    );
  }

  /// The Wake-on-LAN setup typed in, or null while the MAC address is empty.
  WakeOnLanSettings? _wolSettings() {
    final mac = normalizeMac(_wolMac.text);
    if (mac == null) return null;
    final broadcast = _wolBroadcast.text.trim();
    return WakeOnLanSettings(
      mac: mac,
      broadcast: broadcast.isEmpty ? defaultWolBroadcast : broadcast,
      port: int.tryParse(_wolPort.text.trim()) ?? defaultWolPort,
    );
  }

  /// Signs in with what is typed and fills the MAC address from the server's
  /// network cards, so it does not have to be copied over by hand.
  Future<void> _fetchMac() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = true);
    try {
      final (session, updated) = await connectToInstance(
        _build(),
        confirmCertificate: (cert) => confirmCertificateDialog(context, cert),
        askOtp: () => askOtpDialog(context),
      );
      final List<NetInterface> cards;
      try {
        cards = [
          for (final card in await session.system.interfaces())
            if (card.mac != null) card,
        ];
      } finally {
        await session.close();
      }
      _pinnedFingerprint = updated.pinnedFingerprint;
      _lastApiVersion = updated.lastApiVersion;
      if (!mounted) return;
      if (cards.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.wolFetchNone)));
        return;
      }
      var chosen = cards.first;
      if (cards.length > 1) {
        final picked = await showAppChoice<NetInterface>(
          context: context,
          title: l10n.wolChooseCard,
          choices: [
            for (final card in cards)
              appChoice(card, '${card.name} · ${card.mac}'),
          ],
        );
        if (picked == null) return;
        chosen = picked.$1;
      }
      setState(() => _wolMac.text = normalizeMac(chosen.mac!) ?? chosen.mac!);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testing = true);
    try {
      final (session, updated) = await connectToInstance(
        _build(),
        confirmCertificate: (cert) => confirmCertificateDialog(context, cert),
        askOtp: () => askOtpDialog(context),
      );
      final info = await session.systemInfo();
      await session.close();
      _pinnedFingerprint = updated.pinnedFingerprint;
      _lastApiVersion = updated.lastApiVersion;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.testSucceeded(
              '${info['hostname'] ?? ''}',
              '${info['version'] ?? ''}',
            ),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final previous = widget.instance;
    var instance = _build();
    // A different address means a different certificate.
    if (previous != null && previous.url != instance.url) {
      instance = instance.copyWith(pinnedFingerprint: () => null);
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(instancesProvider.notifier).upsert(instance);
    } catch (error) {
      // Stay on the form so what was typed is not lost.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.serverSaveFailed('$error'))),
      );
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isApiKey = _authMethod == AuthMethod.apiKey;
    final keepsSaved = _keepsSavedSecret;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instance == null ? l10n.addServer : l10n.editServer),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                hintText: l10n.fieldNameHint,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('address'),
              controller: _url,
              decoration: InputDecoration(
                labelText: l10n.fieldAddress,
                hintText: l10n.fieldAddressHint,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.validationRequired;
                }
                final address = ServerAddress.tryParse(value);
                if (address == null) return l10n.validationAddress;
                if (isApiKey && !address.isSecure) {
                  return l10n.validationApiKeyHttps;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppSegments<AuthMethod>(
              values: const [AuthMethod.apiKey, AuthMethod.password],
              labels: [l10n.authApiKey, l10n.authPassword],
              icons: const [Icons.key_outlined, Icons.password_outlined],
              selected: _authMethod,
              onChanged: (method) => setState(() {
                _authMethod = method;
                _secret.clear();
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              decoration: InputDecoration(labelText: l10n.fieldUsername),
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.validationRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('secret'),
              controller: _secret,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: isApiKey ? null : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: isApiKey ? l10n.fieldApiKey : l10n.fieldPassword,
                hintText: keepsSaved ? '••••••••' : null,
                helperText: keepsSaved
                    ? (isApiKey ? l10n.fieldApiKeyKeep : l10n.fieldPasswordKeep)
                    : (isApiKey ? l10n.fieldApiKeyHelp : null),
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: _obscure ? l10n.showSecret : l10n.hideSecret,
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) =>
                  keepsSaved || (value != null && value.trim().isNotEmpty)
                  ? null
                  : l10n.validationRequired,
            ),
            const SizedBox(height: 32),
            Text(
              l10n.wolSection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(l10n.wolIntro, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('wolMac'),
              controller: _wolMac,
              decoration: InputDecoration(
                labelText: l10n.wolMac,
                hintText: l10n.wolMacHint,
              ),
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value == null ||
                      value.trim().isEmpty ||
                      normalizeMac(value) != null
                  ? null
                  : l10n.wolMacInvalid,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _testing ? null : _fetchMac,
                icon: const Icon(Icons.download_rounded),
                label: Text(l10n.wolFetch),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('wolBroadcast'),
              controller: _wolBroadcast,
              decoration: InputDecoration(
                labelText: l10n.wolBroadcast,
                hintText: defaultWolBroadcast,
                helperText: l10n.wolBroadcastHelp,
                helperMaxLines: 3,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('wolPort'),
              controller: _wolPort,
              decoration: InputDecoration(
                labelText: l10n.wolPort,
                hintText: '$defaultWolPort',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final port = int.tryParse(text);
                return port != null && isValidPort(port)
                    ? null
                    : l10n.wolPortInvalid;
              },
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(l10n.testConnection),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _testing ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// The text of a Wake-on-LAN field: empty when it is the default.
String _wolText(Object? value, Object defaultValue) =>
    value == null || value == defaultValue ? '' : '$value';
