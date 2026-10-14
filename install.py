#!/usr/bin/env python3
"""Install the dock for the current user, preserving settings and theme."""
import os
from pathlib import Path
import shutil
import subprocess


def install():
    source = Path(__file__).resolve().parent
    home = Path.home()
    data = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share"))) / "dock"
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config")))
    bindir = home / ".local/bin"
    for directory in (data, bindir, config / "systemd/user"):
        directory.mkdir(parents=True, exist_ok=True)
    for name in ("qml", "bin"):
        shutil.copytree(source / name, data / name, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    shutil.copy2(source / "bin/dock", bindir / "dock")
    (bindir / "dock").chmod(0o755)
    subprocess.run([str(bindir / "dock"), "ctl", "init"], check=True)
    # systemd expands percent specifiers; quote paths for homes containing spaces.
    executable = str(bindir / "dock").replace("%", "%%").replace("\\", "\\\\").replace('"', '\\"')
    unit = f'''[Unit]
Description=Dock for Hyprland
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart="{executable}"
Environment=QT_QPA_PLATFORM=wayland
Restart=on-failure
RestartSec=3
'''
    (config / "systemd/user/dock.service").write_text(unit)
    print(f"Installed {bindir / 'dock'}")
    print("Run dock from a Hyprland session. See README.md for autostart.")


if __name__ == "__main__":
    install()
