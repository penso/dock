# Installing Dock on Omarchy

Dock can be installed as a normal Arch package, with pacman tracking its files and dependencies. It runs as a separate user service; it does not replace Omarchy's shell, bar, or configuration tree.

## Install from a checkout now

Run these commands as your normal user inside an Omarchy desktop session:

```sh
git clone --depth 1 https://github.com/penso/dock.git
cd dock
./install-omarchy.sh
```

Until the repository is public, cloning requires GitHub access. No AUR or official Omarchy package is published yet.

The setup script:

1. Uses `omarchy-pkg-add` to install the build tools and declared runtime dependencies.
2. Creates a compact source archive and a SHA-256-checked `PKGBUILD` from the checkout.
3. Runs `makepkg` as your user and installs the resulting `dock-quickshell` package through pacman.
4. Disables the built-in `omarchy.dock` plugin when that plugin exists, so two docks do not overlap.
5. Enables Dock under `graphical-session.target` and starts it for the current session.

Omarchy's existing terminal/sudo flow handles package installation. Settings remain user-owned under `~/.config/dock`. The installed launcher detects classic versus Lua Hyprland dispatchers with a read-only IPC query, so the same command works across both configurations.

Use `--keep-omarchy-dock` to leave the built-in plugin enabled. `--no-start` installs and enables Dock for the next graphical login without starting it or changing Omarchy's running plugin; if your version has a built-in dock, disable that plugin yourself before using both at the same edge.

If your Omarchy channel cannot satisfy `quickshell>=0.3.2`, update through `omarchy update` before retrying. The setup script does not bypass Omarchy's update workflow or install a different Qt stack.

## Start, stop, and configure

```sh
dock enable           # Start now and at graphical login
dock disable          # Stop now and remove graphical-login autostart
dock restart          # Apply an installed update
dock ipc settings     # Open appearance settings
```

The package also adds a **Dock** application entry to Omarchy's launcher. Right-click the dock's grid icon for placement, auto-hide, and appearance controls. The Omarchy theme and your other desktop configuration are not rewritten.

## Update a checkout-built package

```sh
cd /path/to/dock
git pull --ff-only
./install-omarchy.sh
```

Until the package is published to a configured repository, `omarchy update` cannot discover new Dock versions automatically. Once accepted into Omarchy's package repository, updates can use Omarchy's normal package pipeline instead.

## Remove

```sh
dock disable
omarchy-pkg-drop dock-quickshell
```

Your `~/.config/dock` settings are retained. If setup disabled Omarchy's built-in dock and you want it back:

```sh
omarchy-plugin-enable omarchy.dock
```

## Switching from `python3 install.py`

A user-local launcher or service can shadow the package's files. The setup script detects that case rather than silently overwriting those files.

Stop the old installation and remove its autostart entry. If using its service, run `systemctl --user disable --now dock.service`. Move `~/.local/bin/dock` and `$XDG_CONFIG_HOME/systemd/user/dock.service` (default `~/.config/systemd/user/dock.service`) aside, then run `./install-omarchy.sh`. Keep `~/.config/dock` to preserve favorites and appearance settings. The old data directory at `$XDG_DATA_HOME/dock` can be removed once the packaged installation is working. Also quit any dock running directly from the checkout before enabling the packaged copy.

## How this fits Omarchy's distribution model

The Omarchy checkout uses `omarchy-pkg-add` for configured binary repositories and `omarchy-pkg-aur-add` for AUR packages. Its own recipes live separately in [`omacom/omarchy-pkgs`](https://github.com/omacom/omarchy-pkgs), not in the main desktop repository. Accepted recipes are built, signed, and published through `edge` → `rc` → `stable`; users then receive updates through `omarchy update`.

This project provides the pieces needed for that route:

- `packaging/arch/PKGBUILD.in`: the Arch package recipe template.
- `packaging/arch/package.json`: Omarchy's `source: local` metadata with an upstream GitHub Release watch.
- `tools/package_arch.py`: reproducible source archives, real SHA-256 checksums, and materialized recipes.
- `.github/workflows/release.yml`: builds an `any` package and uploads release assets when a version tag is pushed; manual runs produce artifacts only.
- `packaging/dock.service`: a disabled-by-default, package-owned systemd user unit.

The package is architecture-independent QML/Python (`arch=('any')`); Omarchy's repository can publish it for both x86_64 and aarch64. This does not claim that this project has performed an ARM runtime test.

## Maintainer release and submission

1. Make the repository accessible to users and Omarchy's builders.
2. Set `VERSION`, commit the release, then tag and push `v<version>`; for example `v0.1.0` when ready. The tag must match `VERSION`.
3. The release workflow builds `dock-quickshell-<version>-1-any.pkg.tar.zst`, a compact source archive, `SHA256SUMS`, and `dock-quickshell-recipe.tar.gz`. The build uses `makepkg --nodeps` because this script/QML package has no compilation step; dependencies remain declared for installation.
4. Extract the recipe archive and submit its `PKGBUILD` and `.omarchy/package.json` under `pkgbuilds/dock-quickshell/` in `omacom/omarchy-pkgs`. Follow that repository's build and contribution instructions. Its release watch follows the versioned GitHub assets; it does not track a moving branch.
5. Only after acceptance and publication to the user's configured channel can users install with:

```sh
omarchy-pkg-add dock-quickshell
dock enable
```

For a local package build without installing or enabling anything:

```sh
python3 tools/package_arch.py
cd dist/arch
makepkg
```

Use `python3 tools/package_arch.py --release` to generate a recipe referencing the corresponding GitHub Release asset. Its source URL uses `$pkgver`, so Omarchy's upstream watcher can advance both the version and archive checksum.

The Arch package was built in an isolated Arch container. Package layout, installed-launcher lookup, session commands, and dispatcher detection have automated coverage. A full end-to-end install on an Omarchy machine still needs runtime verification.
