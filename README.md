<div align="center">

<img src="assets/icon.png" width="120" alt="Snap It">

# Snap It

**Press a key, the focused macOS window lands exactly where you saved it.**

A menu bar app in the spirit of Divvy: saved window positions, global shortcuts,
one readable config file. Native Swift, no third party dependencies, 1.2 MB.

[![CI](https://github.com/bunlongheng/snap-it/actions/workflows/ci.yml/badge.svg)](https://github.com/bunlongheng/snap-it/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)](#requirements)
[![Dependencies](https://img.shields.io/badge/dependencies-0-black.svg)](#why-it-is-this-small)

</div>

---

## What it does

`cmd` `alt` `←` puts the window on the left half of the screen it is already on.
`cmd` `alt` `→` puts it on the right. There are 16 layouts to start with, and any
of them can be renamed, redrawn on a grid, or bound to a different key.

That is the whole app. It has no window of its own, no account, no network access,
and no background helper.

## Requirements

| | |
|---|---|
| macOS | 13 Ventura or newer, Apple silicon or Intel |
| To install | Nothing. The release is a prebuilt universal app |
| To run | The Accessibility permission, which is what lets any app move another app's windows |
| To build (optional) | Apple's Command Line Tools (`xcode-select --install`). Xcode is **not** needed |

## Install

```bash
curl -fsSL https://snap-it-bheng.vercel.app/install.sh | bash
```

That downloads the prebuilt universal app (2.2 MB), puts it in `/Applications`
and launches it. Nothing to compile, so no Xcode and no Command Line Tools.
The 16 layouts below are already configured, so there is nothing to set up after.

Then **one** manual step, because macOS refuses to let any installer grant it:

| Your macOS | Allow Snap It to move windows |
|---|---|
| 15 Sequoia, 26 Tahoe | Snap It asks on launch. Click **Open System Settings**, then switch **Snap It** on. It is already in the list. |
| 13 Ventura, 14 Sonoma | Same, but if Snap It is not listed under **System Settings → Privacy & Security → Accessibility**, click **+**, press `⌘⇧G`, enter `/Applications` and pick `Snap It.app`. |

That is the whole install. Press `⌥⌘←` on any window to check it worked.

> **Launched it and nothing happened?** That is expected. Snap It has no window,
> no Dock icon and no entry in the app switcher. It lives as a small **rectangle
> split down the middle** at the right hand end of the menu bar, and clicking that
> icon is how you reach all 16 layouts and Settings. If a window refuses to move,
> the Accessibility switch above is still off: Snap It beeps instead of moving
> anything until it is on.

<details>
<summary>What the script does, before you pipe it to bash</summary>

Read it first if you would rather: <https://snap-it-bheng.vercel.app/install.sh>.
It downloads [the latest release](https://github.com/bunlongheng/snap-it/releases/latest),
checks the file really is a zip, unpacks it with `ditto` so the code signature
survives, moves it to `/Applications` (or `~/Applications` if that is not
writable), clears the quarantine flag and opens it. No `sudo`, nothing written
outside `/Applications`.

The quarantine flag is cleared because the app is signed but not notarized, so
Gatekeeper would otherwise block it. Clearing the flag is exactly what right
clicking the app and choosing **Open** does.

</details>

### Or build it from source

Recommended if you want to change it. Needs Apple's Command Line Tools
(`xcode-select --install`); a clean build takes about 12 seconds.

```bash
git clone https://github.com/bunlongheng/snap-it
cd snap-it
make install
```

> **If you are going to rebuild:** an ad hoc signature changes with every build, and
> macOS ties the Accessibility grant to the binary it saw, so a rebuild silently loses
> the permission while System Settings still shows it enabled. Two ways out:
>
> ```bash
> make signing-identity                              # once: a stable self signed identity
> make install SIGN_IDENTITY="Snap It Local Signing" # the grant now survives rebuilds
> ```
>
> Or keep ad hoc signing and run `make reset-permission` after each rebuild, then
> approve it again.

### Updating

Re-run the install command. For the same reason as above, a new release is a new
binary, so macOS asks you to switch Snap It on once more after an update.

## Default shortcuts

<!-- defaults:start -->
| Layout | Shortcut | Region |
|---|---|---|
| Left Half | `⌥⌘←` | 50% x 100% |
| Right Half | `⌥⌘→` | 50% x 100% |
| Maximize | `⌥⌘↑` | 100% x 100% |
| Top Half | `⌃⌥⌘↑` | 100% x 50% |
| Bottom Half | `⌃⌥⌘↓` | 100% x 50% |
| Left Third | `⌥⌘1` | 33% x 100% |
| Center Third | `⌥⌘3` | 33% x 100% |
| Right Third | `⌥⌘5` | 33% x 100% |
| Right Two Thirds | `⌥⌘2` | 67% x 100% |
| Center Two Thirds | `⌃⌥⌘C` | 67% x 100% |
| Top Left Sixth | `⌃⌥⌘1` | 33% x 50% |
| Top Middle Sixth | `⌃⌥⌘2` | 33% x 50% |
| Top Right Sixth | `⌃⌥⌘3` | 33% x 50% |
| Bottom Left Sixth | `⌃⌥⌘4` | 33% x 50% |
| Bottom Middle Sixth | `⌃⌥⌘5` | 33% x 50% |
| Bottom Right Sixth | `⌃⌥⌘6` | 33% x 50% |
<!-- defaults:end -->

Generated from `Config.standard` by `make sync-defaults` - edit the defaults in
`Sources/SnapItKit/Config.swift`, never this table.

If another app already owns one of these, Snap It says so in its menu rather than
failing silently.

## Settings

Click the menu bar icon and choose **Settings**. Each layout has:

- a **grid picker**, drag across it the way you would in Divvy
- a **shortcut recorder**, which releases Snap It's own keys while it listens so
  you can re-record a combination that is already in use

The footer carries a launch at login toggle and a button that reveals the config
file. Gap and grid size live in that file rather than in the window: they are set
once, if ever.

## The config file

Everything lives in `~/Library/Application Support/SnapIt/config.json`. It is
written pretty printed with sorted keys, so editing it by hand and diffing it both
work.

```json
{
  "gap": 0,
  "grid": { "columns": 6, "rows": 6 },
  "layouts": [
    {
      "id": "left-half",
      "name": "Left Half",
      "frame": { "x": 0, "y": 0, "width": 0.5, "height": 1 },
      "shortcut": "cmd+alt+left"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `gap` | Points of space between windows and screen edges, 0 to 64 |
| `grid` | The grid the settings picker snaps to, 1 to 12 in each direction |
| `layouts[].id` | Stable identifier, unique across the file |
| `layouts[].name` | What the menu shows |
| `layouts[].frame` | Fractions of the screen's usable area, origin at the top left |
| `layouts[].shortcut` | `cmd`, `ctrl`, `alt`, `shift` plus one key, for example `cmd+alt+left`. Optional |

Frames are fractions rather than pixels, so one layout means the same thing on a
laptop display and on a 6K monitor. A shortcut must include `cmd`, `ctrl` or `alt`,
so it cannot swallow ordinary typing.

A file that does not parse, names an unknown key, or gives the same shortcut to two
layouts is reported rather than guessed at, and is never overwritten.

## Setting it up on another Mac

```bash
curl -fsSL https://snap-it-bheng.vercel.app/install.sh | bash
```

Then two things are per-machine and cannot be scripted:

| | |
|---|---|
| **Accessibility** | Approve Snap It once, as in [Install](#install). macOS deliberately refuses to let this be automated, so it is one manual toggle on every Mac, forever. |
| **Your layouts** | The defaults are already the shortcut set above, so most people need nothing. To carry over a customised set, copy `~/Library/Application Support/SnapIt/config.json` across and restart the app. |

## Coming from Divvy

```bash
make import-divvy
```

This reads Divvy's own preferences, converts every saved shortcut into a Snap It
layout, and writes the config (your previous one is kept as `config.json.backup`).
Quit Divvy afterwards so the two are not fighting over the same keys.

## Project layout

```
Sources/SnapItKit/   pure logic: layouts, placement maths, shortcut parsing, config file
Sources/SnapIt/      the app: menu bar, hot keys, Accessibility calls, settings window
Tests/               the test suite and its small harness
Resources/           Info.plist template
assets/icon.png      the app icon, turned into an .icns at build time
scripts/             icon builder, linter, signing identity, Divvy importer
web/                 the landing page deployed to Vercel
```

| File | Why it exists |
|---|---|
| `SnapItKit/Placement.swift` | Turns a saved fraction into a rectangle on a specific screen, gaps included |
| `SnapItKit/KeyCombo.swift` | Parses and prints `cmd+alt+left`, the one format the config and the UI share |
| `SnapItKit/Config.swift` | The whole of the app's state, plus the rules a valid config has to satisfy |
| `SnapIt/WindowMover.swift` | The only file that talks to the Accessibility API |
| `SnapIt/HotKeyCenter.swift` | Registers the global shortcuts through the system hot key API |
| `SnapIt/ScreenGeometry.swift` | Converts between AppKit and Accessibility coordinates |

## Development

```bash
make test              # run the test suite
make lint              # compiler warnings, long lines, trailing whitespace, leftover markers
make app               # build build/Snap It.app without installing it
make run               # build it and launch it from ./build
make install           # build it, install to /Applications, launch it
make signing-identity  # create a self signed identity so the grant survives rebuilds
make reset-permission  # clear the Accessibility grant after an ad hoc rebuild
make import-divvy      # convert Divvy's shortcuts into a Snap It config
make uninstall         # remove /Applications/Snap It.app
make dev-web           # serve the landing page on http://localhost:4477
make clean             # delete ./build
```

There is no package manager step and nothing to resolve. `make` calls `swiftc`
directly, which is why a clean build takes about ten seconds.

## Why it is this small

- **Fractions, not pixels.** Four numbers between 0 and 1 describe a layout, so
  multiple displays need no special handling.
- **The system's own hot keys.** `RegisterEventHotKey` hands the app only the
  combinations it registered. There is no event tap, so Snap It never sees another
  keystroke, and no polling loop, so it costs nothing while idle.
- **One source of truth.** The menu, the settings window and the JSON file are the
  same state, so there is no syncing code to get wrong.

## Security notes

- The only permission requested is Accessibility, the minimum needed to move a
  window that belongs to another app.
- No network calls, no analytics, no crash reporting, no login item unless you ask
  for one.
- The config file is the only thing written to disk, under the app's own directory.

## Environment variables

**None.** The app reads no environment variables and stores no credentials. The
landing page in `web/` is static and needs none either, so there is no `.env` file
anywhere in this project and nothing to keep out of the repository.

Deploying the landing page needs the usual Vercel account credentials, which live
in your Vercel account rather than in this repo:

| Name | Where it lives | Needed for |
|---|---|---|
| `VERCEL_TOKEN` | Your Vercel account, or the GitHub repository secrets | Deploying from CI instead of the dashboard |

## Deploying the landing page

`vercel.json` is set up for a static deploy with no build step:

| Setting | Value |
|---|---|
| Framework | none |
| Build command | none |
| Install command | none |
| Output directory | `web` |

```bash
vercel --prod     # or connect the repo in the Vercel dashboard
```

Security headers (CSP, HSTS, `X-Frame-Options`, `Referrer-Policy`,
`Permissions-Policy`) are set in `vercel.json` for every response.

## Licence

MIT. See [LICENSE](LICENSE).
