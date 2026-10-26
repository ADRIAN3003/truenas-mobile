# Checking the unconfirmed parts on a real NAS

Some features were written from the TrueNAS middleware source and the fake
server in the tests, and have not been seen against a real server or phone.
This is a short list of what to try, what should happen, and what to send back
when it does not. Take your time; none of it changes anything on the NAS except
the self-test, which runs a normal S.M.A.R.T. test.

When something is off, the most useful things to send are:

- **Settings > About > Error log > Share** right after it happened.
- The answer of the method in question, from **More > API explorer** (search
  for the method, fill in the parameters shown below, call it, copy the
  result). Remove anything private first.
- The TrueNAS version (**More > Updates**).

## 1. S.M.A.R.T. (disk screen)

Storage > Disks > a disk.

- The card shows the last finished self-test and its result, and the list
  below shows the history, newest first, with power-on hours.
- Start a **Short** test. Within a few seconds the card says it is running with
  a percent, and the bar moves while the screen is open. When it ends the
  result is Passed.
- If a disk refuses (a USB disk, a disk in a RAID controller), the message
  from the server is shown.

If it differs, API explorer:

- `smart.test.results` with `[[["disk", "=", "sda"]]]`. Expected: a list with
  one entry holding `tests` (each with `num`, `description`, `status`,
  `status_verbose`, `remaining`, `lifetime`, `lba_of_first_error`) and, while a
  test runs, `current_test.progress`.
- `smart.test.manual_test` with `[[{"identifier": "<disk identifier>", "type": "SHORT"}]]`.
  Expected: a list with one entry per disk and an `error` that is null when it
  started. The identifier is the `identifier` field of `disk.query`.

## 2. History charts (dashboard > CPU card > History)

- CPU usage and temperature, network per interface, disk temperature per disk,
  and the ARC chart show up for the hour, day, week and month.
- Compare a value with the same chart in the TrueNAS web UI (Reporting). The
  units are the likeliest thing to be wrong: network should be in kilobit/s
  scaled sensibly, ARC in MiB scaled to GiB.

If it differs, API explorer:

- `reporting.netdata_graphs` (25.04) or `reporting.graphs`: no parameters. Note
  each graph's `name`, `vertical_label` and `identifiers`.
- `reporting.netdata_get_data` / `reporting.get_data` with
  `[[{"name": "cpu"}], {"unit": "HOUR"}]` and the same for `arcsize` and for
  `interface` with `"identifier": "<your interface>"`. Note the `legend`
  entries (the app expects the first to be `time`, and `idle` in the `cpu`
  graph) and the first rows of `data`.

## 3. App logs (Apps tab > an app > Logs)

- The last 500 lines appear within a second or two and new lines follow.
  Filter, copy, "last 100 / 500 / 2000 lines" and clear work.
- Turn the phone's wifi off and on: the screen empties and the last lines come
  again (it resubscribes).
- An app with several containers asks which one first.

If nothing appears for an app that is printing, the event source name is the
suspect (`app.container_log_follow` with the arguments). Open the error log:
a refused subscription is written there with the server's words.

## 4. iOS widgets and Shortcuts

- **Widgets**: with the app closed (swiped away), a widget on the home screen
  should still refresh within about 15 minutes. Try it on mobile data over
  Tailscale or your reverse proxy, and, if you pinned a self-signed
  certificate, with that server.
- **Shortcuts**: the Shortcuts app lists Start, Stop and Restart an app and
  Run a cloud sync under TrueNAS Mobile. Siri ("Restart an app in TrueNAS
  Mobile") asks which app, Restart and Stop ask first, and a server whose
  saved password is wrong says so instead of doing nothing.

## 5. Wake-on-LAN

With the NAS shut down (and Wake-on-LAN on in its BIOS), the power button on
its card should start it within a minute on the same network. It cannot be
promised over a VPN or from mobile data unless the router forwards the
broadcast.

## 6. Alert notifications

With alert notifications on, create an alert (for example start a scrub and
pause it, or use a test alert) and wait for the notification. **Tapping it**
should open that server and land on its alerts list, also when the app was
swiped away.
