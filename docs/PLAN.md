# TrueNAS Mobile: implementation plan

A Flutter app for iOS and Android that manages one or more TrueNAS instances
through the official TrueNAS middleware API, supporting TrueNAS 25.04
(Fangtooth) through the newest release.

## 1. What the API looks like (research summary)

Checked against the `truenas/middleware` source (tags TS-25.04.2.6, TS-25.10.7,
TS-26.0.0-BETA.3, TS-27.0.0-RC.1 and `master`) and the TrueNAS docs.

| Topic | Finding | Consequence for the app |
|---|---|---|
| Transport | JSON-RPC 2.0 over WebSocket at `wss://<host>/api/<version>` (also `/api/current`). | One WebSocket client is the whole API layer. |
| REST | Deprecated in 25.04, **removed in 26** ([deprecations page](https://www.truenas.com/docs/scale/26/gettingstarted/deprecations/)). | Never use REST. |
| Legacy `/websocket` (DDP-style) | Still routed, but superseded by JSON-RPC. | Never use it. |
| Versioning | Each release serves every API version it still supports, e.g. 27.0.0-RC.1 serves `v24_10`, `v25_04_0..2`, `v25_10_0..5`, `v27_0_0`. `GET /api/versions` lists them (JSON array). | On connect, fetch `/api/versions`, pick the newest version the app knows; fall back to `current`. |
| Releases in range | 25.04.x, 25.10.x, 26.0.0 (beta/RC), 27.0.0 (RC); `master` is already on `v28_0_0`. The numbering switched from YY.MM to major.0.0 after 25.10. | Version parsing must handle both `25.04.2` and `27.0.0`. |
| Auth | `auth.login_ex` with mechanisms `PASSWORD_PLAIN`, `API_KEY_PLAIN`, `OTP_TOKEN` (2FA step via `auth.login_ex_continue`), `TOKEN_PLAIN`, and `SCRAM` (SHA-512, API keys, newer releases). `auth.generate_token` gives short-lived tokens. | Support API key (recommended) and username+password+2FA. Use SCRAM where the server offers it (`auth.mechanism_choices`). |
| Discovery | `core.get_methods` returns every method with its JSON schema, roles and whether it is a job. | Lets the app reach 100 % of the API without hand-writing every call (see §3). |
| Long tasks | Many methods are *jobs*: the call returns a job id; progress arrives as `core.get_jobs` events. | A shared job tracker with progress UI. |
| Events | `core.subscribe` → `collection_update` notifications (e.g. `reporting.realtime`, `alert.list`, `core.get_jobs`). | Live dashboard, alerts and job progress over the same socket. |
| Files | HTTP `/_upload` (multipart, auth token) and `/_download/...` (URL from `core.download`). | Config backup/restore, certificate and update uploads, debug download. |
| Shell | `/_shell` WebSocket. | Optional in-app terminal (`xterm` package). |
| Namespace churn | 25.04→25.10 removed `k8s_to_docker`, `smartctl`, `acme_registration`, `rdma_interface`; 25.10 added NVMe-oF (`nvmet.*`), ZFS resource APIs. 25.10→26/27 removed Incus `virt.*` and added `container.*`, `webshare`, `s3`, `zfs.tier`, `zpool.*`. | Feature screens are gated on method availability, not on version strings. |

## 2. Architecture

```
lib/
  core/
    api/        JsonRpcClient (WebSocket, request ids, timeouts, reconnect),
                AuthService, VersionNegotiator, JobTracker, EventBus,
                FileTransfer (/_upload, /_download), MethodCatalog (core.get_methods)
    instances/  Instance model, repository (encrypted local storage)
    security/   TLS: trust-on-first-use certificate pinning for self-signed certs
    theme/      Material 3, dynamic color, light/dark
    router/     go_router
  features/
    instances/  add/edit/switch servers, connection test
    dashboard/  system info, CPU/RAM/network/ARC live charts, alerts, pools
    storage/    pools, datasets, zvols, snapshots, scrub/resilver, disks, SMART
    shares/     SMB, NFS, iSCSI, NVMe-oF
    data_protection/ snapshot tasks, replication, cloud sync, rsync, cloud backup
    apps/       Docker apps: installed, catalog, install/upgrade, logs
    virtualization/ VMs (vm.*), Incus (virt.*, 25.04/25.10), containers (container.*, 26+)
    network/    interfaces, static routes, DNS, global config
    credentials/ users, groups, privileges, API keys, certificates, SSH keypairs,
                 directory services, KMIP
    system/     general/advanced settings, services, updates, boot environments,
                tunables, cron, init scripts, reporting, audit, support, shutdown/reboot
    jobs/       running and recent jobs with progress
    alerts/     list, dismiss, alert services
    shell/      terminal
    api_explorer/ generic, schema-driven access to every method
  shared/       widgets, forms, formatting (bytes, durations)
```

Packages (pinned in `pubspec.yaml`): `flutter_riverpod` (state), `go_router`,
`web_socket_channel`, `http`, `flutter_secure_storage` (credentials),
`freezed` + `json_serializable` (models), `fl_chart`, `xterm`,
`dynamic_color`, `local_auth` (biometric unlock), `intl`.

### Multiple instances
- Each instance stores name, URL, auth type, credentials (secure storage only),
  pinned certificate fingerprint, last-seen version and colour/icon.
- A drawer/switcher keeps one live connection per *open* instance; the home
  screen shows all instances with health (online, alerts count, pool status).
- Optional app lock with biometrics.

### Version compatibility strategy
1. `GET https://host/api/versions` → choose newest supported entry, else `current`.
2. After login, call `core.get_methods` once per session and cache it keyed by
   server version; every feature checks `catalog.has('container.query')` etc.
3. Typed models are generated from the newest API, with lenient decoding
   (unknown fields ignored, missing ones nullable) so older servers decode too.
4. CI runs the client tests against recorded fixtures from 25.04, 25.10 and
   26/27 responses.

### Full API coverage
Hand-built screens cover the day-to-day areas listed above. Everything else
stays reachable through the **API explorer**: browse namespaces, see the method
doc, fill a form generated from its JSON schema, run it, and follow the job.
That keeps "everything the API offers" true on every server version, including
methods added after the app was built.

### UX principles
Material 3 with dynamic colour, bottom navigation (Dashboard, Storage, Shares,
Apps, More), pull-to-refresh, live updates through subscriptions, confirmation
dialogs that name the object for destructive actions (pool export, dataset
delete), job progress sheets, skeleton loading, offline/reconnecting banner,
tablet layouts with a navigation rail.

## 3. Repository, CI and releases

- `.gitignore` for Flutter/Dart/Android/iOS/IDE, keystores and secrets.
- `LICENSE` (MIT by default), `README.md` with features, screenshots,
  supported versions, build and install instructions, trademark note.
- `CONTRIBUTING.md`, issue templates, Dependabot for pub and Actions.
- **CI** (`.github/workflows/ci.yml`, on PR and push): `flutter analyze`,
  `dart format --set-exit-if-changed`, `flutter test`, debug APK build on
  Ubuntu, unsigned iOS build (`--no-codesign`) on macOS.
- **Release** (`.github/workflows/release.yml`, on `v*` tags): builds
  split-per-ABI and universal APKs plus an AAB, and an IPA, then publishes a
  GitHub Release with generated notes.
  - Android is signed with a keystore from repository secrets
    (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
    `ANDROID_STORE_PASSWORD`); without them it falls back to debug signing.
  - iOS: without an Apple Developer account the IPA is unsigned (installable
    with AltStore/Sideloadly, which re-sign it). With an account, add the
    certificate and provisioning profile as secrets and the workflow signs it.

## 4. Milestones

| # | Milestone | Contents |
|---|---|---|
| 0 | Scaffold | Flutter project, lint rules, license, README, CI, release workflow |
| 1 | API core | JSON-RPC client, version negotiation, auth (API key, password, 2FA), TLS pinning, jobs, events, method catalog, unit tests with fixtures |
| 2 | Instances | add/edit/delete, connection test, secure storage, switcher, app lock |
| 3 | Dashboard and alerts | system info, live reporting charts, alerts, jobs view |
| 4 | Storage | pools, datasets, snapshots, disks, scrub, replication and snapshot tasks |
| 5 | Shares and services | SMB, NFS, iSCSI, NVMe-oF, services start/stop/config |
| 6 | Apps and virtualization | Docker apps, VMs, Incus / containers by version |
| 7 | Accounts, network, system | users, groups, API keys, certs, network, updates, boot envs, settings, power |
| 8 | API explorer and shell | schema-driven forms for every method, terminal |
| 9 | Polish and 1.0 | tablet layouts, localisation, accessibility, screenshots, store prep |

Each milestone ships as its own PR with tests; a tagged release can be cut at
any point after milestone 2.

## 5. Open questions (defaults used until answered)

1. **License**: MIT (default), Apache-2.0, or GPL-3.0?
2. **App name and ID**: "TrueNAS" is an iXsystems trademark, so for a public
   store listing a name like "NAS Manager for TrueNAS" is safer. Default name
   *TrueNAS Mobile* with ID `io.github.adrian3003.truenasmobile`.
3. **iOS signing**: unsigned IPA (default) or do you have an Apple Developer account?
4. **Android signing**: generate a release keystore and add it as secrets
   (default: debug-signed until you add them).
5. **Distribution**: GitHub Releases only (default), or also Play Store / F-Droid / App Store?
6. **Oldest version**: 25.04 (default); 24.10 is nearly free to add because
   newer servers still serve the `v24_10` API.
7. **Languages**: English only at first (default, i18n-ready), add Hungarian?
8. **Self-signed certificates**: trust on first use with fingerprint pinning (default).
9. **Auth**: API key recommended, username + password + 2FA also supported (default both).
