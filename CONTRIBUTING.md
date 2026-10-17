# Contributing

Thanks for helping with TrueNAS Mobile. Bug reports, feature ideas,
translations and pull requests are all welcome. By contributing you agree
that your work is released under the [MIT licence](LICENSE).

## Reporting bugs and asking for features

Use the [issue templates](https://github.com/ADRIAN3003/truenas-mobile/issues/new/choose).
For a bug, include the app version, your phone and OS, your TrueNAS version
and what you did. Whether the NAS sits behind a reverse proxy matters too.
Never paste passwords, API keys or tokens.

## Setting up

You need Flutter **3.47.7** (the version pinned in
[`.github/workflows`](.github/workflows)).

```sh
flutter pub get
flutter run
```

You can sign in to any TrueNAS 25.04 or newer server. Most tests run against a
fake middleware (`test/support/fake_truenas_server.dart`), so you do not need
a NAS to work on the app.

## Before you open a pull request

Run what CI runs:

```sh
dart format lib test        # CI fails on unformatted code
flutter analyze
flutter test
```

Then:

- Keep the change focused. One fix or feature per pull request.
- Add or update tests. Extend the fake server rather than mocking.
- Every user-facing string goes in both `lib/l10n/app_en.arb` and
  `lib/l10n/app_hu.arb`. The generated code in `lib/l10n/generated` is
  committed, so run `flutter gen-l10n` and include it.
- If the UI changed, update the README screenshots with
  `SCREENSHOTS=1 flutter test test/screenshots --update-goldens`, and put
  before and after images in the pull request.
- Name the branch after what it does, in kebab-case, for example
  `shell-reverse-proxy`.
- Fill in the [pull request template](.github/pull_request_template.md),
  including which TrueNAS version you tested against.

## Project layout and conventions

[`AGENTS.md`](AGENTS.md) is the working guide for the codebase. It covers the
folder layout, the TrueNAS API quirks and the UI conventions, and it is worth
reading before a larger change. The main points:

- `lib/core/api/` talks JSON-RPC over the WebSocket at `/api/<version>` and
  has no Flutter imports. Gate features on `core.get_methods`, not on version
  strings, so one build works from 25.04 to the latest release.
- Do not assume the NAS's own port or paths. Many people run it behind a
  reverse proxy on 443.
- Screens live in `lib/features/<area>/`. Shared building blocks are in
  `lib/shared/`. Use the adaptive widgets there (`AppDialog`, `AppSwitch`,
  `AppRefreshIndicator` and so on) instead of the bare Material ones.
- On iOS the chrome is `liquid_glass_widgets`. Read
  `.claude/skills/liquid-glass-widgets/SKILL.md` before touching it.

## Translations

To add a language or fix a translation, follow the steps in the
[README](README.md#translations).

## AI-assisted contributions

Most of this project was written with an AI assistant, and AI-assisted pull
requests are fine. You are still responsible for what you submit: read it,
run it and test it on a device or against the fake server before asking
anyone to review it.

## Security

Please do not open a public issue for a security problem. Contact the
maintainer privately through their [GitHub profile](https://github.com/ADRIAN3003)
instead.
