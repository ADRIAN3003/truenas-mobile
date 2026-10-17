import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/server_address.dart';
import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
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
    for (final c in [_name, _url, _username, _secret]) {
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
    );
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
