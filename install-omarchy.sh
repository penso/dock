#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
NO_START=false
KEEP_OMARCHY_DOCK=false
for arg in "$@"; do
  case "$arg" in
    --no-start) NO_START=true ;;
    --keep-omarchy-dock) KEEP_OMARCHY_DOCK=true ;;
    *) echo "Usage: ./install-omarchy.sh [--no-start] [--keep-omarchy-dock]" >&2; exit 2 ;;
  esac
done
if (( EUID == 0 )); then
  echo "Run this as your normal user. Package installation will request sudo when needed." >&2
  exit 1
fi
if ! command -v omarchy-pkg-add >/dev/null || ! command -v pacman >/dev/null; then
  echo "This installer needs Omarchy. For other desktops, use python3 install.py." >&2
  exit 1
fi
if [[ -e $HOME/.local/bin/dock || -L $HOME/.local/bin/dock || -e ${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/dock.service || -L ${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/dock.service ]]; then
  echo "A user-local Dock launcher or service exists. See docs/omarchy.md for migration before installing the system package." >&2
  exit 1
fi

omarchy-pkg-add base-devel python quickshell python-gobject qt6-declarative qt6-svg qt6-imageformats hicolor-icon-theme
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dock-package.XXXXXXXX")
trap 'rm -rf -- "$BUILD_DIR"' EXIT
python3 "$ROOT/tools/package_arch.py" --output "$BUILD_DIR"
(
  cd "$BUILD_DIR"
  makepkg --syncdeps --install --force --noconfirm
)
if ! $NO_START && ! $KEEP_OMARCHY_DOCK && [[ -n ${OMARCHY_PATH:-} && -f $OMARCHY_PATH/shell/plugins/dock/manifest.json ]]; then
  omarchy-plugin-disable omarchy.dock
fi
dock enable --no-start
if ! $NO_START; then
  dock restart
fi
echo "Dock is installed as dock-quickshell and enabled for your graphical session."
