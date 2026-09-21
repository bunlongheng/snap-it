#!/bin/bash
# Snap It installer. Downloads the prebuilt universal app, puts it in
# /Applications and launches it. No Xcode, no toolchain, no compile.
#
#   curl -fsSL https://snap-it-bheng.vercel.app/install.sh | bash
#
# Building from source is still fully supported: see the README.
set -euo pipefail

APP="Snap It"
REPO="bunlongheng/snap-it"
ASSET="Snap-It-universal.zip"
URL="https://github.com/$REPO/releases/latest/download/$ASSET"
MIN_MAJOR=13

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'; else B=; D=; R=; fi
say() { printf '%s\n' "$*"; }
die() { printf '\n%serror:%s %s\n\n' "${B}" "${R}" "$*" >&2; exit 1; }

# --- 1. is this Mac supported ------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "Snap It is a macOS app; this is $(uname -s)."

os="$(sw_vers -productVersion)"
major="${os%%.*}"
case "$major" in
  13) name="Ventura" ;;
  14) name="Sonoma" ;;
  15) name="Sequoia" ;;
  26) name="Tahoe" ;;
  *)  name="" ;;
esac

if [ "$major" -lt "$MIN_MAJOR" ]; then
  die "Snap It needs macOS 13 Ventura or newer. This Mac is on macOS $os."
fi

say ""
say "${B}Snap It${R} ${D}- macOS $os${name:+ $name}, $(uname -m)${R}"

# --- 2. download -------------------------------------------------------------
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "  downloading"
curl -fsSL --retry 3 --connect-timeout 20 "$URL" -o "$tmp/$ASSET" \
  || die "could not download $URL
       Check your connection, or build from source:
       git clone https://github.com/$REPO && cd snap-it && make install"

# A 404 page or an HTML error would also land here, so confirm it is a zip.
head -c 2 "$tmp/$ASSET" | grep -q PK || die "the download was not a zip file. Try again in a moment."

# --- 3. unpack ---------------------------------------------------------------
# ditto is the only unpacker that keeps a bundle's code signature intact.
ditto -x -k "$tmp/$ASSET" "$tmp/unpacked" || die "could not unpack the download."
[ -d "$tmp/unpacked/$APP.app" ] || die "the download did not contain $APP.app."

# --- 4. choose a destination -------------------------------------------------
dest="/Applications"
if [ ! -w "$dest" ]; then
  dest="$HOME/Applications"
  mkdir -p "$dest"
  say "  ${D}/Applications is not writable, installing to ~/Applications instead${R}"
fi

# --- 5. replace any existing copy --------------------------------------------
osascript -e "quit app \"$APP\"" >/dev/null 2>&1 || true
rm -rf "$dest/$APP.app"
mv "$tmp/unpacked/$APP.app" "$dest/$APP.app" || die "could not write to $dest."

# The app is signed but not notarized, so macOS would block a downloaded copy
# until the quarantine flag is cleared. Clearing it is what a right click and
# Open does, without making you hunt through Settings for the Open Anyway button.
xattr -dr com.apple.quarantine "$dest/$APP.app" 2>/dev/null || true

say "  installed ${B}$dest/$APP.app${R}"

# --- 6. launch and confirm it really came up ---------------------------------
# Snap It is LSUIElement, so it has no Dock icon, no window and no entry in the
# app switcher. Launching it looks exactly like nothing happening, which is why
# this waits for the process and then says where to look.
open "$dest/$APP.app" || die "installed, but could not launch it. Open it from $dest."

running=false
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if pgrep -f "$dest/$APP.app" >/dev/null 2>&1; then running=true; break; fi
  sleep 0.5
done

if $running; then
  say "  running  ${D}(menu bar only, it has no window and no Dock icon)${R}"
else
  die "installed to $dest but it did not stay running. Open it by hand and note any message."
fi

# --- 7. the one thing that cannot be automated -------------------------------
# macOS deliberately refuses to let any script grant Accessibility. The app
# asks for it on launch; these are the exact steps for THIS macOS version.
cat <<BANNER

  ${B}Where it is${R}

  Snap It has no window and no Dock icon on purpose. Look at the right hand end
  of your menu bar for a small ${B}rectangle split down the middle${R}. Click it and
  you will see all 16 layouts. That icon is the whole interface.

  ${D}Not there? A full menu bar can hide icons behind the notch. Hold Cmd and drag${R}
  ${D}a menu bar icon left to make room, or check Control Centre in System Settings.${R}

  ${B}One last step: let Snap It move windows${R}

  macOS is showing a permission prompt right now. Click ${B}Open System Settings${R}
  on it, then turn ${B}Snap It${R} on. If you dismissed it, or it did not appear
  because you had already granted it, do this instead:

BANNER

if [ "$major" -ge 15 ]; then
  cat <<STEPS
    1. Open ${B}System Settings${R}  ${D}(Apple menu, System Settings)${R}
    2. ${B}Privacy & Security${R} in the sidebar
    3. ${B}Accessibility${R}
    4. Switch ${B}Snap It${R} on

  ${D}On macOS $major${name:+ $name} the app is already in that list once it has asked.${R}
STEPS
else
  cat <<STEPS
    1. Open ${B}System Settings${R}  ${D}(Apple menu, System Settings)${R}
    2. ${B}Privacy & Security${R} in the sidebar
    3. ${B}Accessibility${R}
    4. Switch ${B}Snap It${R} on

  ${D}On macOS $major${name:+ $name}, if Snap It is not listed yet, click the ${B}+${D} button,${R}
  ${D}press ${B}Cmd Shift G${D}, enter $dest and pick ${B}Snap It.app${D}.${R}
STEPS
fi

cat <<DONE

  ${B}Then you are done.${R} Focus any window and press:

    ${B}Cmd Alt Left${R}   left half        ${B}Cmd Alt Up${R}  maximise
    ${B}Cmd Alt Right${R}  right half       ${B}Cmd Alt 1/3/5${R}  thirds

  16 layouts are set up already, nothing to configure. The menu bar icon
  lists them all, and Settings lets you redraw or rebind any of them.

  ${D}If the window does not move, the Accessibility switch above is still off.${R}
  ${D}Snap It beeps rather than moving anything until it is on.${R}

  ${D}Uninstall: rm -rf "$dest/$APP.app"${R}

DONE
