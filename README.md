# Elyx Preview for Nix

Packages Elyx Preview `0.0.1-preview.16889.g86cc7388a1` for **x86_64-linux**
from a privately supplied archive. This project contains only packaging files;
the archive and application binary are excluded from the flake and Git.
The import script accepts any archive filename and records its Nix source
metadata automatically; no preset checksum is required. There is no download
URL for the application. Nixpkgs is pinned in `flake.lock`.

## Run, build, or install

```sh
cd /home/blade0/Projects/elyx-nix
# One-time private import (also required on each additional build machine):
./import-archive.sh /path/to/any-name.tar.gz
nix run .
nix build .
./result/bin/elyx-preview
nix run .#cli -- --version

# Install the command and desktop launcher into your user profile:
nix profile add .#elyx
```

The GUI launcher is `elyx-preview`; the CLI is `elyx`. The application menu
entry is **Elyx Preview**. `nix run .` launches the GUI; `nix run .#cli` runs
the CLI.
Flakes and the `nix-command` experimental feature must be enabled.
The package uses Nixpkgs' AppImage FHS wrapper and does not require FUSE.

## NixOS or Home Manager

Add this input to your configuration's flake:

```nix
inputs.elyx.url = "path:/home/blade0/Projects/elyx-nix";
```

Then use one of these in a module that has access to `inputs`:

```nix
# NixOS:
environment.systemPackages = [ inputs.elyx.packages.x86_64-linux.default ];

# Home Manager:
home.packages = [ inputs.elyx.packages.x86_64-linux.default ];
```

Alternatively, use `inputs.elyx.overlays.default` and install `pkgs.elyx`.
The flake's package output allows this proprietary binary explicitly; when
using the overlay or calling `package.nix` yourself, allow `elyx` through your
own Nixpkgs unfree policy.

## Source and updates

Run `./import-archive.sh /path/to/any-name.tar.gz` to select or replace the
private archive. Neither its filename nor its checksum needs to match a preset
value. The archive must contain exactly one regular `.AppImage` file; its name
and containing directory can vary.

The script imports the archive into the local Nix store and writes
`archive-source.nix` with automatically generated source metadata. This small
metadata file belongs with the packaging files; it contains no application
bytes. Nix uses the generated hash to locate the selected archive, so builds
remain reproducible and `nix run .` still works without `--impure`.

To select another build, rerun the import script, update the package's `version`
if needed, and run `nix build .` and `nix flake check`. The installer patch may
need adjustment if the app's implementation changes. Keep the original archive
so you can reimport it after Nix garbage collection if needed.

## CLI and skill installation

The package makes the bundled CLI and daemon runnable outside the AppImage
environment on NixOS. The application's skill installer is patched at build
time to make copied skills writable before it adds version metadata. Only the
patching script is included here; the private application sources remain in
the local Nix store.

Use the app's **Install Elyx CLI and skills** action to install the CLI link
into `~/.local/bin` and skills into `~/.claude/skills` and `~/.agents/skills`.
Installing again refreshes app-managed skills. Add `~/.local/bin` to your
shell's PATH if necessary. A Nix profile install already provides the `elyx`
CLI; the app then installs only the missing skills.
